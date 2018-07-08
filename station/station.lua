--Dependencies.
local c = require("component")
local lights = require("lights")
local buttons = require("buttonAPI")
local graphics = require("graphics")
local gButtons = require("gButtonAPI4")
local gKeyboard = require("gKeyboard")
local event = require("event")
local ser = require("serialization")
local thread = require("thread")
local d = require("computer")
local matrix = require("matrix")
local sides = require("sides")
--local u = require("unicode")

--Graphic cards.
local GPU = c.proxy("332a93bc-f0a6-4c71-9460-d7a7d6ee0d2c")
local APU = c.proxy("4ba6d276-efab-474c-ba48-bcbd7fd62353")
local invGPU = c.proxy("dfac05d3-bbb6-48ac-88da-98ce65a5a01c")

--Movement button blueprint.
local movements = {
  {"forward","/\\",sides.front,50,50},
  {"left","<",sides.left,35,65},
  {"back","\\/",sides.back,50,65},
  {"right",">",sides.right,65,65},
  {"up","/\\",sides.up,82,50},
  {"down","\\/",sides.down,82,65}
}

-- Scan information
local SCAN_TYPE_SLICE = 1
local SCAN_TYPE_LAYER = 2
local SCAN_TYPE_COMPLETE = 4

--Variables.
local history = {{2,0},{2,0}}
local terrain = {}
local blocks = {}
--local localPos = {0,0,0}
local charge = 100
local facing = "W" -- S W N E (+Z -X -Z +X)
local yVal = -3

local currentSlotBtn = {"inv1","inv2"}
local currentSelection = false
local inventoryTitles = {"Label","Amount","Name","Damage"}
local inventory = {}

local count = 0
local isRunning = true

--Digit screen addresses.
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



--Functions.
local function addBlock(pos,color)
  local x = c.glasses.addCube3D()
  x.set3DPos(table.unpack(pos))
  x.setColor(table.unpack(color))
  x.setAlpha(0.7)
  x.setScale(0.8)
  return x
end

local function addHistory(x,screen,hist)
  --APU.bind("b11c404d-c54e-4409-af0c-70f31a20b5f6")
  --GPU.bind("d5c01595-a68b-4323-aaa0-5f20af1124bf")
  --print(APU.maxResolution())
  x = tostring(x)
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


local function removeBlocks(arr)
  print("Removing blocks...")
  for i = 1, #arr do
    local blockIndex = arr[#arr - i + 1]
    print("Removing a block...", blockIndex)
    c.glasses.removeObject(blocks[blockIndex].getID())
    table.remove(blocks, blockIndex)
    print("Removing block...")
  end
end

local function transform(arr,dir)
  local removal = {}
  for i,d in ipairs(arr) do
    local x, y, z = d.get3DPos()
    if dir == sides.forward then
      x = x + 1
    elseif dir == sides.back then
      x = x - 1
    elseif dir == sides.up then
      y = y - 1
    elseif dir == sides.down then
      y = y + 1
    end
    if math.abs(x) > 4 or y < -3 or y > 18 then
      table.insert(removal, i)
    else
      d.set3DPos(x, y, z) -- Only update the position if it's going to be kept. Extra effeciency!
    end
  end
  removeBlocks(removal)
end

local function rotate(rot)
  for _,xz in ipairs(blocks) do
    xz.set3DPos(matrix.rotate({xz.get3DPos()},rot))
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

local function extractBlocks(blocks)
  local result = {}
  while blocks > 0 do
    table.insert(result, blocks & 1)
    blocks = blocks >> 1
  end
  return result
end

local function buildCompleteScan(slices)
  -- addBlock({x, y, z}, {255, 0, 0})
  for i, slice in pairs(slices) do
    for j, chunk in pairs(slice) do
      -- local blockData = extractBlocks(chunk)
      -- for k, d in pairs(blockData) do
      local k = 1
      while chunk > 0 do
        -- The positioning gets a little tricky here... Lemme run this on a whiteboard real quick lol. Ok.
        if chunk & 1 == 1 then
          local x = -((k - 1) % 9 - 4) -- Should be fixed. Oh wow, that easy? Let's hope it was that easy
          local y = j*7 - 4 - math.floor((k - 1)/9) -- Yeah that seems correct (might be a lil easier)
          local z = -5 + i
          local thisHue = 360 - ((y+5))/9*360

          local b = addBlock({x,y,z},{HSL(thisHue, 1, 0.5, 1)}) --Should it return a table? extractBlocks? Yes.
          os.sleep(0)
          table.insert(blocks,b)
        end
        chunk = chunk >> 1
        k = k + 1
      end
    end
    break
  end
end

local function buildScanSlice(scanInfo, blockData)
  print(scanInfo >> 6)
  transform(blocks, scanInfo >> 6)
end

-- local function receiveScanData(_,_,_,_,_,msg1,msg2,msg3,msg4)
local function receiveScanData(scanInfo, blockData)
  print("Received", scanInfo)
  addHistory(tostring(blockData),APU,2)
  if scanInfo & SCAN_TYPE_COMPLETE > 0 then -- Nasty Lua, 0 is not TRUE!!!
    buildCompleteScan(blockData)
  elseif scanInfo & SCAN_TYPE_SLICE > 0 then
    buildScanSlice(scanInfo, blockData)
  elseif scanInfo & SCAN_TYPE_LAYER > 0 then
    -- transform the blocks and add the layer
  end
  if msg1 == "scanData" then
    yVal = -3
  else
  end
end

local inventorySlotButtons = {}
local function writeSlots(data)
  for i=1,16 do
    --local limData = {data[i][1],data[i][2],data[i][3]}
    --print(data[i][2])
    buttons.Label(inventorySlotButtons[i],{data[i][1],data[i][2],data[i][3]})
    --print(data[i][2])
  end
end

local function selectSlot(this)
  local k = nil
  local colorK = 0x008000
  if currentSelection then
    k = 1
    colorK = 0x008000 --Green.
  else
    k = 2
    colorK = 0xFF0000 --Red.
  end
  buttons.Color(currentSlotBtn[k])
  buttons.Color(this,colorK)
  currentSlotBtn[k] = this--buttons.buttons[this].customData[1]
  graphics.fillRect(114,1,46,16,0x000000)
  --graphics.addText(115,2,inventory[buttons.buttons[currentSlotBtn[k]].customData[1]])
  local h = inventory[buttons.buttons[currentSlotBtn[k]].customData[1]]
  --for i=2,#h do
  --  if h[2] ~= "Empty" then
  --    h[i] = inventoryTitles[i-1] .." : "..h[i]
  --  else
  --    h = inventory[buttons.buttons[currentSlotBtn[k]].customData[1]]
  --  end
  --end
  local y = 3
  graphics.addText(115,2,h[1])
  for i=2,#h+1 do
    if h[i] ~= "Empty" then
      graphics.addText(115,y,inventoryTitles[i-1].." : "..h[i])
    else
      graphics.addText(115,y,h[i])
    end
    y=y+1
  end

  --graphics.addText(115,2,h)
  os.sleep(0.4)
  --buttons.Color(this)
  --print(this)
end

--Interfaces.

local function drawInventory()
  graphics.SetGPU(invGPU)
  --Change background color.
  invGPU.setBackground(0xfffdd0)
  local maxW, maxH = invGPU.maxResolution()
  invGPU.fill(1,1,maxW,maxH," ")
  --Draw info tab.
  graphics.fillRect(113,1,48,16,0x9966cc)
  graphics.fillRect(114,1,46,16,0x000000)
  --[[graphics.addFloatingText(111,2,{"Jag heter Simön.","hurr durr","Potatoe Chips"})
  graphics.addText(111,8,{"I am","a color"})
  graphics.addText(111,10,{"that is","Green"},0x06983e)--]]
  --Slot buttons.
  local k = 1
  for y=1,4 do
    for x=1,4 do
      buttons.createNewButton("inv"..k,{"Slot " .. tostring(k),"Empty"},"slots",x*18-17,y*9-8,14,7,0xe69500,selectSlot,"6c916656-426a-4b4b-b766-7756b2e5f0a2")
      buttons.buttons[tostring("inv"..k)].customData[1] = k
      table.insert(inventorySlotButtons,tostring("inv"..k))
      inventory[k] = {"Slot "..k,"Empty"}
      k = k + 1
    end
  end
  --Selection button mode.
  buttons.createNewButton("invSel","Selection",nil,76,1,30,7,0xFF0000,function(x)
    currentSelection = not currentSelection
    if currentSelection then
      buttons.Color(x,0x008000) --Green.
    else
      buttons.Color(x)
    end
  end,"6c916656-426a-4b4b-b766-7756b2e5f0a2")
  --Swap between the selected slots.
  buttons.createNewButton("invSwap","Swap Items",nil,76,10,30,7,0x7fff00,function(x)
    local slotsK = {buttons.buttons[currentSlotBtn[1]].customData[1],buttons.buttons[currentSlotBtn[2]].customData[1]}
    print("Swapped items in slot " .. slotsK[1] .. " and " .. slotsK[2] .. ".")
    buttons.Color(x,0x008000)
    os.sleep(0.4)
    buttons.Color(x)
  end,"6c916656-426a-4b4b-b766-7756b2e5f0a2")
  --Scan the Robot's inventory.
  buttons.createNewButton("getInventory","Scan Inventory",nil,76,19,30,7,0x7fff00,function(x)
    c.tunnel.send("getInventory")
    buttons.Color(x,0x008000)
    os.sleep(0.4)
    buttons.Color(x)
  end,"6c916656-426a-4b4b-b766-7756b2e5f0a2")
  --Swap the currently selected item on that mode to the hand.
  buttons.createNewButton("equip","Equip",nil,76,28,30,7,0x7fff00,function(x)
    buttons.Color(x,0x008000)
    os.sleep(0.4)
    buttons.Color(x)
  end,"6c916656-426a-4b4b-b766-7756b2e5f0a2")
  buttons.Color(currentSlotBtn[1],0x008000)
  buttons.Color(currentSlotBtn[2],0xFF0000)
end

local function drawGeneral()

end

local function turn(direction)
  c.tunnel.send("mov", direction)
  if direction == sides.left then
    rotate(matrix.TCW)
  else
    rotate(matrix.TACW)
  end
end

local function move(direction)
  c.tunnel.send("mov", direction)
end

--Program check.
for i=1,5 do d.beep() end -- You wanting to test something?

--Main.
gButtons.initialize()

gButtons.createNewButton("scan",nil,"Scan",5,5,35,14,{255,0,0},0.4,function(x)
  gButtons.Color(x,{0,255,0})
  --c.glasses.removeAll()
  c.tunnel.send("scan")
  os.sleep(0.4)
  gButtons.Color(x)
end)

gButtons.createNewButton("clear",nil,"Clear Cubes",42,5,64,14,{255,0,0},0.4,function(x)
  gButtons.Color(x,{0,255,0})
  --c.glasses.removeAll()
  c.glasses.removeAll()
  os.sleep(0.4)
  gButtons.Color(x)
  blocks= {}
end)

for _,i in ipairs(movements) do
  local callback = move
  if i[3] & 4 == 4 then -- If 3rd bit is 1, then it is a left/right movement
    callback = turn
  end
  gButtons.createNewButton(i[1],"movement",i[2],i[4],i[5],15,15,{255,0,0},0.4,function(x)
    callback(i[3]) -- Either `move` or `turn`
    gButtons.Color(x,{0,255,0})
    os.sleep(0.4)
    gButtons.Color(x)
  end)
    -- gButtons.createNewButton(i[1],"movement",i[2],i[4],i[5],15,15,{255,0,0},0.4,function(x)
    --   move(i[3])
    --   local _,_,_,_,_,r = event.pull(2,"modem_message")
    --   if r == nil then r = "moved" end
    --   addHistory(tostring(r),APU,2)
    --   if r ~= "blocked" then
    --     transform(blocks,i[1])
    --   end --Ah nevermind
    --   gButtons.Color(x,{0,255,0})
    --   os.sleep(0.4)
    --   gButtons.Color(x)
    -- end)
  -- gButtons.createNewButton(i[1],"movement",i[2],i[4],i[5],15,15,{255,0,0},0.4,function(x))
end --{"forward","/\\","require('component').robot.move(3)",50,50},

buttons.initialize(invGPU)

drawInventory()
--createNewButton(name,group,x,y,w,h,color,callback,scr)
--buttons.createNewButton("test",nil,2,2,20,20,0xe69500,function() addHistory("Yes.",APU,2) end,"6c916656-426a-4b4b-b766-7756b2e5f0a2")



local gThread = thread.create(function()
  while true do gButtons.update() end
end)

local bThread = thread.create(function()
  while true do buttons.update(1/20) end
end)

local function update()
  --print(event.pull(1/20,"modem_message"))
  --thread.create(function() gButtons.update() end)
  local packet = {event.pull(1/20,"modem_message")}
  if packet[6] == "info" then
    print(packet[7])
  end
  if packet[6] == "charge" then
    --[[lights.digit(3,digitDisplays[1],0xff033d)
    lights.digit(5,digitDisplays[2],0xff033d)
    lights.digit(9,digitDisplays[3],0xff033d)--]]
    charge = math.floor(packet[7] * 100 + 0.25)
    local currentDisplay = 3
    --print(charge)
    for _,i in ipairs(digitDisplays) do
      lights.clear(i)
    end

    for i=string.len(charge),1,-1 do
      local value = string.sub(charge,i,i) or nil
      if value == nil then
        --lights.clear(digitDisplays[currentDisplay])
        break
      end
      value = tonumber(value)
      --lights.digit(value,digitDisplays[value],0xff033d)
      lights.digit(value,digitDisplays[currentDisplay],0xff033d)
      currentDisplay = currentDisplay - 1
      --print(value)
    end


  end
  --print(o)
  if packet[6] == "scanData" then
    receiveScanData(packet[7], ser.unserialize(packet[8]))
    addHistory("Received Blocks from Remote.",APU,2)
    -- event.listen("modem_message",receiveScanData)
    -- addHistory("Enabled Data Transfer",APU,2)
  end
  -- if packet[6] == "scanDataComplete" then
  --   event.ignore("modem_message",receiveScanData)
  --   addHistory("Disabled Data Transfer",APU,2)
  -- end
  --thread.create(function() gButtons.update() end)
  --os.sleep(1/20)
  if packet[6] == "inventory" then
    --print("Got new Inventory Scan.")
    addHistory("Got new Inventory Scan.",APU,2)
    local newInventoryScan = {}
    local k = ser.unserialize(packet[7])
    for i in pairs(k) do
      table.insert(newInventoryScan,ser.unserialize(k[i]))
    end
    inventory = newInventoryScan
    writeSlots(inventory)
  end
end

local terminate = thread.create(function()
  event.pull("interrupted")
  print("Killed the program.")
  gThread:kill()
  bThread:kill()
  isRunning = false
  --os.exit()
end)

while true do
  update()
  if not isRunning then os.exit() end
end
