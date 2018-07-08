local gpu = require("component").gpu
local event = require("event")
local thread = require("thread")


local API = {}

API.buttons = {}
API.buttonsNames = {}
API.groups = {}
API.groupsNames = {}


local function has_value (tab, val)
  for index, value in ipairs(tab) do
    if value == val then
      return true
    end
  end
  return false
end

function API.initialize(graph)
  if graph ~= nil then
    gpu = graph
  end
  API.buttons = {}
  API.buttonsNames = {}
  API.groups = {}
  API.groupsNames = {}
end

function API.OverwriteGPU(newGPU)
  gpu = newGPU
end

local function colorBtn(btn,color,label)
  local background = gpu.getBackground()
  local x,y = API.buttons[btn].posRect[1],API.buttons[btn].posRect[2]
  local w,h = API.buttons[btn].sizeRect[1],API.buttons[btn].sizeRect[2]
  gpu.setBackground(color)
  gpu.fill(x,y,w,h," ")
  if type(label) == "table" then
    for i in pairs(label) do
      gpu.set(x,y+i,string.sub(label[i],1,14))
    end
  else
    gpu.set(x+2,y,label)
  end
  gpu.setBackground(background)
end

function API.createNewButton(name,label,group,x,y,w,h,color,callback,scr)
  if group ~= nil then
    if not has_value(API.groupsNames,group) then
      table.insert(API.groupsNames,group)
    end
    if API.groups[group] ~= nil then
      k = API.groups[group]
      table.insert(k,name)
      API.groups[group] = k
    else
      API.groups[group] = {name}
    end
  end
  table.insert(API.buttonsNames, name)
  API.buttons[name] = {
    posRect = {x,y},
    sizeRect = {w,h},
    colorRect = color,
    state = false,
    customData = {},
    callbk = callback,
    vsble = true,
    screen = scr,
    label = label,
    currentColor = color,
    currentLabel = label
    --currentColor = color
    --posTxt = {x + (w / 2) - ((string.len(label) / 2) + (w / 4.5)),y + (h / 3)}
  }
  colorBtn(name,color,label)
  return true
end
function API.update(refreshRate)
  local e,screen,xV,yV = event.pull(refreshRate,"touch")
  if e == nil then return end

  for i in pairs(API.buttonsNames) do
    if
       API.buttons[API.buttonsNames[i]].screen == screen and API.buttons[API.buttonsNames[i]].vsble and xV >= API.buttons[API.buttonsNames[i]].posRect[1] and xV <= API.buttons[API.buttonsNames[i]].posRect[1]+API.buttons[API.buttonsNames[i]].sizeRect[1]-1 and
        yV >= API.buttons[API.buttonsNames[i]].posRect[2] and yV <= API.buttons[API.buttonsNames[i]].posRect[2]+API.buttons[API.buttonsNames[i]].sizeRect[2]-1 then

          local t = thread.create(function()

            local _,err = pcall(function() API.buttons[API.buttonsNames[i]].callbk(API.buttonsNames[i]) end)

            if err then print("Error on " .. API.buttonsNames[i] .. " press:" .. "\n" .. err) end

          end)
    end
  end
end

local function isGroup(val)
  for i in pairs(API.groupsNames) do
    if val == API.groupsNames[i] then
      return true,API.groupsNames[i]
    end
  end
  return false
end


function API.printGroups()
  for i in pairs(API.groupsNames) do
    print(API.groupsNames[i] .. ":")
    for d in pairs(API.groups[API.groupsNames[i]]) do
      print(API.groups[API.groupsNames[i]][d])
    end
  end
end

function API.Visibility(button,vsbility)
  local aGroup = false
  local groupN = ""

  aGroup,groupN = isGroup(button)
  if not aGroup then
    API.buttons[button].vsble = vsbility
    if not vsbility then
      API.buttons[button]["lbl"].setScale(0)
      API.buttons[button]["rect"].setAlpha(0)
    else
      API.buttons[button]["lbl"].setScale(1)
      API.buttons[button]["rect"].setAlpha(API.buttons[button]["alphaRect"])
    end
  else
    for d in pairs(API.groups[groupN]) do
      API.buttons[API.groups[groupN][d]].vsble = vsbility
      if not vsbility then
        API.buttons[API.groups[groupN][d]]["lbl"].setScale(0)
        API.buttons[API.groups[groupN][d]]["rect"].setAlpha(0)
      else
        API.buttons[API.groups[groupN][d]]["lbl"].setScale(1)
        API.buttons[API.groups[groupN][d]]["rect"].setAlpha(API.buttons[API.groups[groupN][d]]["alphaRect"])
      end
    end
  end
end

function API.Color(button,color)
  local aGroup = false
  local groupN = ""
  aGroup,groupN = isGroup(button)

  if color == nil then
    if aGroup then
      for d in pairs(API.groups[groupN]) do
        --API.buttons[API.groups[groupN][d]].rect.setColor(API.buttons[API.groups[groupN][d]].colorRect)
        colorBtn(API.buttons[API.groups[groupN][d]],API.buttons[API.groups[groupN][d]].colorRect,API.buttons[API.groups[groupN][d]].currentLabel)
        API.buttons[API.groups[groupN][d]].colorRect = color
      end
    else
      --API.buttons[button].rect.setColor(table.unpack(API.buttons[button].colorRect))
      colorBtn(button,API.buttons[button].colorRect,API.buttons[button].currentLabel)
      API.buttons[button].currentColor = API.buttons[button].colorRect
    end
  else
    --button,API.buttons[button].currentColor = color
    if aGroup then
      for d in pairs(API.groups[groupN]) do
        --API.buttons[API.groups[groupN][d]].rect.setColor(table.unpack(color))
        colorBtn(API.buttons[API.groups[groupN][d]],color,API.buttons[API.groups[groupN][d]].currentLabel)
        API.buttons[API.groups[groupN][d]].currentColor = color
      end
    else
      --API.buttons[button].rect.setColor(table.unpack(color))
      colorBtn(button,color,API.buttons[button].currentLabel)
      API.buttons[button].currentColor = color
    end
  end
end

function API.Label(button,newLabel)
  colorBtn(button,API.buttons[button].currentColor,newLabel)
  API.buttons[button].currentLabel = newLabel
  return true
end

function API.addToGroup(button,group)
  if group ~= nil then
    if not has_value(API.groupsNames,group) then
      table.insert(API.groupsNames,group)
    end
    if API.groups[group] ~= nil then
      k = API.groups[group]
      table.insert(k,button)
      API.groups[group] = k
    else
      API.groups[group] = {button}
    end
  end
end

return API
