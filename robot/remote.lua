local computer = require("computer")
c = require("component")
local event = require("event")
local ser = require("serialization")
local tty = require("tty")
local thread = require("thread")
local sides = require("sides")

local SCAN_TYPE_SLICE = 1
local SCAN_TYPE_LAYER = 2
local SCAN_TYPE_COMPLETE = 3

local ORIENTATIONS = {sides.north, sides.east, sides.south, sides.east}
local orientation = 1 -- Indicates which of the elements in the ORIENTATIONS list is the current

local hardValues = {}
local terrain = {}

--c.tunnel.send()
local function compress(val)
  val = ser.serialize(val)
  val = c.data.deflate(val)
  --[[local t = {}
  for i=1,#val/4,4 do
    table.insert(t,c.data.deflate(ser.serialize(val[i])))
    table.insert(t,c.data.deflate(ser.serialize(val[i+1])))
    table.insert(t,c.data.deflate(ser.serialize(val[i+2])))
    table.insert(t,c.data.deflate(ser.serialize(val[i+3])))
  end
  ser.serialize(t)--]]
  return val
end

local function decompress(val)
  val = c.data.inflate(val)
  val = ser.unserialize(val)
  return val
end

-- Convert a geolyzer scan result into a single 64-bit number
local function blocksToBits(scanResult, blockCount)
  local result = 0
  local blockCount = blockCount or 64 -- Allow capping the number of blocks scanned
  for i, v in pairs(scanResult) do
    if (i > blockCount) then break end -- Break if it goes over the block count
    result = result << 1 -- Shift the bits left
    if v ~= 0 then -- A block was found
      result = result | 1 -- set the right-most bit to 1
    end
  end
  return result
end

-- Scan the blocks in a slice when moving along the XZ plane.
-- orientation: Orientation of the slice
-- distance: Distance of the slice from the robot
local function scanSlice(facing, distance)
  local result = {}
  if facing & 1 == 0 then
    distance = -distance -- If the robot is facing North or West, negate the distance
  end
  for i = 0, 2 do -- Scan each slice vertically
    local blocks = nil
    if facing & 4 == 4 then -- The robot is oriented on the East/West axis
      blocks = blocksToBits(c.geolyzer.scan(distance, -4, -3 + i*7, 1, 9, 7), 63)
    else -- The robot is oriented on the North/South axis
      blocks = blocksToBits(c.geolyzer.scan(-4, distance, -3 + i*7, 9, 1, 7), 63)
    end
    table.insert(result, blocks)
  end
  return result
end

-- Scan a flat layer. Used when the robot moves up or down
-- distance: The distance of the layer from the robot
local function scanLayer(distance)
  return {
    blocksToBits(c.geolyzer.scan(-4, -4, distance, 9, 7, 1)),
    blocksToBits(c.geolyzer.scan(-4,  3, distance, 9, 2, 1), 18) -- Only 18 blocks were scanned here
  }
end

-- Do a complete scan by scanning the slices.Does not need to
-- take orientation into account
local function scan()
  local result = {}
  for i=-4,4 do
    local slice = scanSlice(sides.south, i)
    table.insert(result, slice)
  end
  return result
end

-- The info that should be sent along with the block data
-- scan orientation
-- Scan type: layer, slice, complete scan
-- 000 - 000
-- First three bits: scan orientation, last three bits: scan type
local function sendTerrain(facing, scanType, blockData)
  local scanInfo = 0
  if scanType ~= SCAN_TYPE_COMPLETE then
    scanInfo = facing << 3
  end
  scanInfo = scanInfo | scanType
  c.tunnel.send("scanData", scanInfo, ser.serialize(blockData)) -- I don't think deflating it will give any benefit in this case since it's just numbers.
end

local function move(direction)
  result, reason = c.robot.move(direction)
  if result then
    -- Scan the new blocks...
    -- Give the station the new blocks
  end
  return result, reason
end

local function turn(direction)
  if direction == true then -- Colckwise rotation
    orientation = orientation % 4 + 1 -- If orientation goes to 5, cycle down to 1
  else -- Counterclockwise/Anticlockwise rotation
    orientation = (orientation - 2) % 4 + 1 -- If orientation goes to 0, then cycle up to 4.
  end
  result, reason = c.robot.turn(direction)
  -- Tell the station that it rotated
  return result, reason
end

-- Used for when the robot moves backwards, it will flip the orientation and scan as if it was
-- facing forwards
local function flippedOrientation()
  return (orientation + 1) % 4 + 1
end

thread.create(function()
  os.sleep(3)
  tty.clear()
  print("Initilizing ..")
  --os.execute("/bin/components.lua")
  --c.gpu.bind("125bb046-a2c9-4182-8459-785265229229")
end):detach()

local function receive(_,_,_,_,_,msg1,msg2,msg3,msg4)
  --computer.beep()
  terrain = {}
  if msg1 == "scan" then
    computer.beep()
    print("Scanning...")
    local terrain = scan()
    sendTerrain(nil, SCAN_TYPE_COMPLETE, terrain)
    computer.beep()
    print("Scan complete.")
    -- print("Starting Sequence ..")
    -- local _,err = pcall(function()
    -- terrain = scan()end)
    -- if err then print(err) end
    -- print(#terrain .. " entries.")
    -- c.tunnel.send("scanData")
    -- os.sleep(1)
    -- for i in pairs(terrain) do
    --   c.tunnel.send(terrain[i])
    --   print(terrain[i])
    -- end
    -- print("Data Sent.")
    -- os.sleep(1)
    -- c.tunnel.send("scanDataComplete")
  end
  if msg1 == "mov" then
    local result, reason = nil,nil
    result, reason = load("return " .. msg2)()
    if not result then
    --print(reason)
      print("Blocked")
      c.tunnel.send("blocked")
      return
    end
    print("Moved")
    c.tunnel.send("moved")
  end
end

event.listen("modem_message",receive)

local function update()
  os.sleep(1/20)
end

while true do update() end
