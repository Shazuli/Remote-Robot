local computer = require("computer")
c = require("component")
local event = require("event")
local ser = require("serialization")
local tty = require("tty")
local thread = require("thread")

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

local function scan()
  local x = {}
  print("Analyzing ..")
  for i=-4,4 do
    for d=-4,4 do
      table.insert(x,c.geolyzer.scan(i,d))
    end
  end
  print("Done Analyzing.")
  return x
end

thread.create(function()
  os.sleep(5)
  tty.clear()
  print("Initilizing ..")
  --os.execute("/bin/components.lua")
  --c.gpu.bind("125bb046-a2c9-4182-8459-785265229229")
end):detach()



local function receive(_,_,_,_,_,msg1,msg2,msg3,msg4)
  --computer.beep()
  terrain = {}
  if msg1 == "scan" then
    print("Starting Sequence ..")
    --[[for x in pairs(hardValues) do
      for z in pairs(hardValues[x]) do
        for y in pairs(hardValues[x][z]) do
          c.gpu.set(1,6,x .. " " .. y .. " " .. z)
          if hardValues[x][z][y] > 0 then
            table.insert(terrain,{x,y,z})
            --print(x .. " " .. y .. " " .. z)
            break
          end
        end
      end
    end--]]
    --local x,z = -4,-4
    for x=-4,4 do
      --x = x + 1
      for z=-4,4 do
        local tile = c.geolyzer.scan(x,z)
        --z = z + 1
        --os.sleep(2)
        --print(tile)
        for y=#tile,1,-1 do
          --print(y)
          if tile[y] ~= 0 then
            table.insert(terrain,{x,y-33,z})
            --print("Found: ",x,y,z)
            --break
          end
          if y < 31 then
            break
          end
        end
      end
    end
    print("Calculation Complete.")
    print(#terrain .. " entries.")
    print("Sending Data ..")
    c.tunnel.send("scanData")
    os.sleep(1)
    for i=1,#terrain,4 do
      os.sleep(1/20)
      c.tunnel.send(
        compress(terrain[i]),
        compress(terrain[i+1]),
        compress(terrain[i+2]),
        compress(terrain[i+3])
      )
    end
    print("Data Sent.")
    os.sleep(1)
    c.tunnel.send("scanDataComplete")
  end
  if msg1 == "mov" then
    local status,err = pcall(function() load(msg2)() end)
    if err then
      print(err)
    end
  end
end

event.listen("modem_message",receive)

local function update()
  os.sleep(1/20)
end

while true do update() end
