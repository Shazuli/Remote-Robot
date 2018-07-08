local computer = require("computer")
c = require("component")
local event = require("event")
local ser = require("serialization")
local tty = require("tty")
local thread = require("thread")
local sides = require("sides")

local SCAN_TYPE_SLICE = 1
local SCAN_TYPE_LAYER = 2
local SCAN_TYPE_COMPLETE = 4

local ORIENTATIONS = {sides.north, sides.east, sides.south, sides.west}
local orientation = 2 -- Indicates which of the elements in the ORIENTATIONS list is the current

local hardValues = {}
local terrain = {}
local charge = 1

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

local function turnOff()
  c.tunnel.send("info","Shutting Down ..")
  computer.shutdown()
end

--event.listen("energy_low",turnOff)

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
-- forward/backwards
-- scan orientation
-- Scan type: layer, slice, complete scan
-- 00 - 000 - 000
-- First three bits: scan orientation, last three bits: scan type
local function sendTerrain(direction, facing, scanType, blockData)
  local scanInfo = scanType
  if direction then
    scanInfo = scanInfo | (direction << 6)
  end
  if facing then
    scanInfo = scanInfo | (facing << 3)
  end
  c.tunnel.send("scanData", scanInfo, ser.serialize(blockData)) -- I don't think deflating it will give any benefit in this case since it's just numbers.
end

local function move(direction)
  local result, reason = c.robot.move(direction)
  if result then
    if direction & 2 == 2 then -- Forward/backwards indicated by 2nd bit
      local facing = ORIENTATIONS[orientation]
      if direction == sides.back then -- If backwards, flip the 1st bit
        facing = facing ~ 1 -- This will flip the 1st bit from whatever it currently is. 1 -> 0, 0 -> 1
      end
      print(direction)
      sendTerrain(direction, facing, SCAN_TYPE_SLICE, scanSlice(orientation, 4))
    else -- Up/down

    end
  end
  return result, reason
end

local function turn(direction)
  if direction == true then -- Clockwise rotation
    orientation = orientation % 4 + 1 -- If orientation goes to 5, cycle down to 1
  else -- Counterclockwise/Anticlockwise rotation
    orientation = (orientation - 2) % 4 + 1 -- If orientation goes to 0, then cycle up to 4.
  end
  result, reason = c.robot.turn(direction)
  print(orientation)
  return result, reason
end

-- Used for when the robot moves backwards, it will flip the orientation and scan as if it was
-- facing forwards
local function flippedOrientation()
  return (orientation + 1) % 4 + 1
end
local function initilize()
  --Some stuff.
end

thread.create(function()
  os.sleep(3)
  tty.clear()
  print("Initilizing ..")
  --os.execute("/bin/components.lua")
  --c.gpu.bind("125bb046-a2c9-4182-8459-785265229229")
  initilize()
  print("Initilizing Complete")
end):detach()

local function receive(_,_,_,_,_,msg1,msg2,msg3,msg4)
  --computer.beep()
  terrain = {}
  if msg1 == "scan" then
    computer.beep()
    print("Scanning...")
    local terrain = scan()
    sendTerrain(nil, nil, SCAN_TYPE_COMPLETE, terrain)
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
    if msg2 & 4 == 4 then -- left/right movement, indicated by the 3rd bit of msg2. 10X, if X is 0, then turn right, if X is 1, then turn left.
      turn(msg2 == sides.right)
    else
      move(msg2) --Whatever other movement, use here.
    end
  end
  if msg1 == "getInventory" then
    local inventory = {}
    for i=1,16 do
      c.robot.select(i)
      local stack = {c.inventory_controller.getStackInInternalSlot()}
      --os.sleep(1)
      --print(stack["name"])
      if #stack > 0 then
        --print(stack[1][1])
        stack = {
          "Slot "..i,
          stack[1]["label"],
          math.floor(stack[1]["size"]).."/"..math.floor(stack[1]["maxSize"]),
          stack[1]["name"],
          math.floor(stack[1]["maxDamage"]-stack[1]["damage"]).."/"..math.floor(stack[1]["maxDamage"])
        }--,stack[1]["name"]
      else
        stack = {"Slot "..i,"Empty"}
      end
      stack = ser.serialize(stack)
      table.insert(inventory,stack)
    end
    c.tunnel.send("inventory",ser.serialize(inventory))
  end
end

event.listen("modem_message",receive)

local tCharge = thread.create(function()
  while true do
    charge = computer.energy()/computer.maxEnergy()
    if charge < 0.03 then turnOff() end
    c.tunnel.send("charge",charge)
    --print(charge)
    os.sleep(20)
  end
end)

local function update()
  os.sleep(1/20)
end

while true do update() end
