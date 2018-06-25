local c = require("component")
local lights = require("lights")
local gButtons = require("gButtonAPI4")
local gKeyboard = require("gKeyboard")
local event = require("event")
local ser = require("serialization")
local thread = require("thread")
local d = require("computer")
local matrix = require("matrix")

local GPU = c.proxy("332a93bc-f0a6-4c71-9460-d7a7d6ee0d2c")
local APU = c.proxy("4ba6d276-efab-474c-ba48-bcbd7fd62353")
--local glasses = c.glasses
local movements = {
  {"forward","/\\","c.robot.move(3)",50,50},
  {"left","<","c.robot.turn(false)",35,65},
  {"back","\\/","c.robot.move(2)",50,65},
  {"right",">","c.robot.turn(true)",65,65},
  {"up","/\\","c.robot.move(1)",82,50},
  {"down","\\/","c.robot.move(0)",82,65}
}
local history = {{2,0},{2,0}}
local terrain = {}
local blocks = {}
local localPos = {0,0,0}
local facing = "W" -- S W N E (+Z -X -Z +X)
local yVal = -3

local count = 0


local digitDisplays = {
  {
    "a87d9238-f46e-4b17-b605-6d8771fba4c4",
    "28dfb050-4f70-4bf8-b221-cc84ab43c660",
    "fef15435-a434-4e33-a3ca-3f725e02dd7f",
    "c0941fad-d5fb-4dce-b356-724431e6b66c"
  },
  {
    "d5a80dc6-963c-4fb5-98ea-711ebb2ff1eb",
    "c868c412-22f5-4605-8e4a-b4bce3e1320c",
    "19b54b1e-8970-4305-9294-d3582d85d06d",
    "c06effa6-bada-4ddc-8578-c46d155b4250"
  },
  {
    "6191d4e0-715f-4c8c-a98e-8960c79c26ab",
    "54ab4452-b63f-4b43-a1e1-13208eac1628",
    "84948db9-81dd-4646-932f-a047ecdef4d7",
    "f226bacf-7af6-47ad-be01-6bb31fcfda9b"
  }
}

local function compress(tab)
  tab = ser.serialize(tab)
  tab = c.data.deflate(tab)
  return tab
end

local function decompress(val)
  val = c.data.inflate(val)
  val = ser.unserialize(val)
  return val
end

local function addBlock(pos,color)
  local x = c.glasses.addCube3D()
  x.set3DPos(table.unpack(pos))
  x.setColor(table.unpack(color))
  x.setAlpha(0.7)
  x.setScale(0.8)
  return x
end

local function addHistory(x,screen,hist)
  APU.bind("b11c404d-c54e-4409-af0c-70f31a20b5f6")
  GPU.bind("d5c01595-a68b-4323-aaa0-5f20af1124bf")
  --print(APU.maxResolution())
  screen.fill(1,1,80,25," ")
  table.insert(history[hist],x)
  history[hist][1] = history[hist][1] + 1
  if #history[hist] > 25 then
    history[hist][2] = history[hist][2] + 1
  end
  for i=3+history[hist][2],history[hist][1] do
    screen.set(1,i-2-history[hist][2],history[hist][i])
  end
  --APU.set(1,history[1],x)
  --history[1] = history[1] + 1
end

local function checkBoundaries(arr)
  for _,i in ipairs(arr) do
    for _,d in ipairs(i) do
      local x,_,z = d.get3DPos()
      --print(table.unpack(j))
      --[[if x > 4 or x < -4 then
        d.setAlpha(0)
      else
        d.setAlpha(0.7)
      end
      if z > 4 or z < -4 then
        d.setAlpha(0)
      else
        d.setAlpha(0.7)
      end--]]
      if x >= -4 and x <= 4 and z >= -4 and z <= 4 then
        d.setAlpha(0.7)
      else
        d.setAlpha(0)
      end
    end
  end
end

local function transform(arr,dir)
  for _,i in ipairs(arr) do
    for _,d in ipairs(i) do
      local o = {d.get3DPos()}
      if dir == "forward" then
        d.set3DPos(o[1]+1,o[2],o[3])
      elseif dir == "back" then
        d.set3DPos(o[1]-1,o[2],o[3])
      elseif dir == "up" then
        d.set3DPos(o[1],o[2]-1,o[3])
      elseif dir == "down" then
        d.set3DPos(o[1],o[2]+1,o[3])
      end
    end
  end
  checkBoundaries(arr)
end

local function rotate(rot)
  for _,y in ipairs(blocks) do
    local o = {}
    for _,xz in ipairs(y) do
      table.insert(o,{xz.get3DPos()})
    end
    for i,xz in ipairs(y) do
      xz.set3DPos(matrix.rotate({xz.get3DPos()},rot))
    end
  end
end

local function HSL(hue, saturation, lightness, alpha)
    if hue < 0 or hue > 360 then
        return 0, 0, 0, alpha
    end
    if saturation < 0 or saturation > 1 then
        return 0, 0, 0, alpha
    end
    if lightness < 0 or lightness > 1 then
        return 0, 0, 0, alpha
    end
    local chroma = (1 - math.abs(2 * lightness - 1)) * saturation
    local h = hue/60
    local x =(1 - math.abs(h % 2 - 1)) * chroma
    local r, g, b = 0, 0, 0
    if h < 1 then
        r,g,b=chroma,x,0
    elseif h < 2 then
        r,b,g=x,chroma,0
    elseif h < 3 then
        r,g,b=0,chroma,x
    elseif h < 4 then
        r,g,b=0,x,chroma
    elseif h < 5 then
        r,g,b=x,0,chroma
    else
        r,g,b=chroma,0,x
    end
    local m = lightness - chroma/2
    return (r+m)*255,(g+m)*255,(b+m)*255
end

--[[lights.digit(3,digitDisplays[1],0xff033d)
lights.digit(5,digitDisplays[2],0xff033d)
lights.digit(9,digitDisplays[3],0xff033d)--]]

--GPU.set(25,5,"Le GPU")
--APU.set(25,5,"La APU")

for i=1,5 do d.beep() end

local function receiveScanData(_,_,_,_,_,msg1,msg2,msg3,msg4)
  --print(msg1)
  addHistory(msg1,APU,2)
  if msg1 == "scanData" then
    yVal = -3
  else
    --[[addBlock(table.unpack(decompress(msg1)),{0,255,0})
    addBlock(table.unpack(decompress(msg2)),{0,255,0})
    addBlock(table.unpack(decompress(msg3)),{0,255,0})
    addBlock(table.unpack(decompress(msg4)),{0,255,0})--]]
    local coord = {decompress(msg1),decompress(msg2),decompress(msg3),decompress(msg4)}
    for i in pairs(coord) do
      yVal = coord[i][2] + 4
      local thisHue = 360 - ((coord[i][1]+5))/9*360
      local b = addBlock({coord[i][1],coord[i][2],coord[i][3]},{HSL(thisHue, 1, 0.5, 1)})
      table.insert(terrain,coord[i])
      --table.insert(blocks,b)
      --blocks[yVal][#blocks[yVal+1]] = b
      --table.insert(blocks[yVal],b)
      --blocks[yVal] = b
      thread.create(function()
        --print(yVal)
        if blocks[yVal] == nil then
          blocks[yVal] = {b}
        else
          table.insert(blocks[yVal],b)
        end
      end)

      --addHistory(yVal,GPU,1)
      --print(yVal)
      --table.insert(blocks,b)
      --if coord[i][2] then print(coord[i][1],coord[i][2],coord[i][3],thisHue) end
    end
  end
end
--event,_,linkingCard,_,_,msg1,msg2,msg3,msg4
--event.listen("modem_message",receiveScanData)

gButtons.initialize()

gButtons.createNewButton("scan",nil,"Scan",5,5,35,14,{255,0,0},0.4,function(x)
  gButtons.Color(x,{0,255,0})
  --c.glasses.removeAll()
  c.tunnel.send("scan")
  os.sleep(0.4)
  gButtons.Color(x)
end)

--[[gButtons.createNewButton("test",nil,"Rotate",5,21,35,14,{255,0,0},0.4,function(x)
  --addHistory(tostring(#blocks[1]),GPU,1)
  for _,y in ipairs(blocks) do
    local o = {}
    for _,xz in ipairs(y) do
      table.insert(o,{xz.get3DPos()})
    end
    for i,xz in ipairs(y) do
      xz.set3DPos(matrix.rotate({xz.get3DPos()},matrix.TCW))
    end
  end

  gButtons.Color(x,{0,255,0})
  os.sleep(0.4)
  gButtons.Color(x)
end)--]]
--name,group,label,x,y,w,h,color,alpha,callback
--[[gButtons.createNewButton("forward","movement","/\\",50,50,15,15,{255,0,0},0.4,function(x)
  c.tunnel.send("mov","require('component').robot.move(3)")
  gButtons.Color(x,{0,255,0})
  os.sleep(0.4)
  gButtons.Color(x)
end)--]]
for _,i in ipairs(movements) do
  gButtons.createNewButton(i[1],"movement",i[2],i[4],i[5],15,15,{255,0,0},0.4,function(x)
    c.tunnel.send("mov",i[3])
    if x == "left" then
      rotate(matrix.TCW)
    end
    if x == "right" then
      rotate(matrix.TACW)
    end
    transform(blocks,i[1])
    gButtons.Color(x,{0,255,0})
    os.sleep(0.4)
    gButtons.Color(x)
  end)
end --{"forward","/\\","require('component').robot.move(3)",50,50},

local gThread = thread.create(function()
  while true do gButtons.update() end
end)

local function update()
  --print(event.pull(1/20,"modem_message"))
  --thread.create(function() gButtons.update() end)
  local _,_,_,_,_,o = event.pull(1/20,"modem_message")
  --print(o)
  if o == "scanData" then
    event.listen("modem_message",receiveScanData)
    addHistory("Enabled Data Transfer",APU,2)
  end
  if o == "scanDataComplete" then
    event.ignore("modem_message",receiveScanData)
    addHistory("Disabled Data Transfer",APU,2)
  end
  --thread.create(function() gButtons.update() end)
  --os.sleep(1/20)
end

while true do update() end
