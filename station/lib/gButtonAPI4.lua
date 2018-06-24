local glasses = require("component").glasses
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

function API.initialize()
  glasses.removeAll()
  API.buttons = {}
  API.buttonsNames = {}
  API.groups = {}
  API.groupsNames = {}
end

function API.createNewButton(name,group,label,x,y,w,h,color,alpha,callback)
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
    rect = glasses.addRect(),
    lbl = glasses.addTextLabel(),
    posRect = {x,y},
    sizeRect = {w,h},
    colorRect = color,
    alphaRect = alpha,
    state = false,
    customData = {},
    callbk = callback,
    vsble = true,
    txt = label,
    posTxt = {x + (w / 2) - ((string.len(label) / 2) + (w / 4.5)),y + (h / 3)}
  }


  API.buttons[name]["rect"].setPosition(x,y)
  API.buttons[name]["rect"].setSize(w,h)
  API.buttons[name]["rect"].setColor(table.unpack(color))
  API.buttons[name]["rect"].setAlpha(alpha)

  API.buttons[name]["lbl"].setPosition(API.buttons[name]["posTxt"][1],API.buttons[name]["posTxt"][2])
  API.buttons[name]["lbl"].setText(label)
  API.buttons[name]["lbl"].setScale(1)
  API.buttons[name]["lbl"].setColor(255,255,255)
  return true
end
function API.update()
  local e,_,_,xV,yV = event.pull(1/100,"interact_overlay")
  if e == nil then return end

  for i in pairs(API.buttonsNames) do
    if
        API.buttons[API.buttonsNames[i]].vsble and xV >= API.buttons[API.buttonsNames[i]].posRect[1] and xV <= API.buttons[API.buttonsNames[i]].posRect[1]+API.buttons[API.buttonsNames[i]].sizeRect[1] and
        yV >= API.buttons[API.buttonsNames[i]].posRect[2] and yV <= API.buttons[API.buttonsNames[i]].posRect[2]+API.buttons[API.buttonsNames[i]].sizeRect[2] then

          t = thread.create(function()

            local _,err = pcall(function() API.buttons[API.buttonsNames[i]].callbk(API.buttonsNames[i]) end)

            if err then print("Error on " .. API.buttonsNames[i] .. " press:" .. "\n" .. err) end

            --print(t:status())
            --t:kill()
          end)
          --os.sleep(2)
          --print(t:status())
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

function API.visibility(button,vsbility)
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
        API.buttons[API.groups[groupN][d]].rect.setColor(API.buttons[API.groups[groupN][d]].colorRect)
      end
    else
      API.buttons[button].rect.setColor(table.unpack(API.buttons[button].colorRect))
    end
  else
    if aGroup then
      for d in pairs(API.groups[groupN]) do
        API.buttons[API.groups[groupN][d]].rect.setColor(table.unpack(color))
      end
    else
      API.buttons[button].rect.setColor(table.unpack(color))
    end
  end
end

function API.Opacity(button,opacity)
  local aGroup,groupN = isGroup(button)

  if opacity == nil then
    if aGroup then
      for d in pairs(API.groups[groupN]) do
        --API.buttons[API.groups[groupN][d]].lbl.setText(API.buttons[API.groups[groupN][d]].txt)
        API.buttons[API.groups[groupN][d]].rect.setAlpha(API.buttons[API.groups[groupN][d]].alphaRect)
      end
    else
      --API.buttons[button].lbl.setText(API.buttons[button].txt)
      API.buttons[button].rect.setAlpha(API.buttons[button].alphaRect)
    end
  else
    if aGroup then
      for d in pairs(API.groups[groupN]) do
        --API.buttons[API.groups[groupN][d]].lbl.setText(label)
        API.buttons[API.groups[groupN][d]].rect.setAlpha(opacity)
      end
    else
      API.buttons[button].rect.setAlpha(opacity)
    end
  end
end

function API.Label(button,label)
  local aGroup,groupN = isGroup(button)

  if label == nil then
    if aGroup then
      for d in pairs(API.groups[groupN]) do
        API.buttons[API.groups[groupN][d]].lbl.setText(API.buttons[API.groups[groupN][d]].txt)
      end
    else
      API.buttons[button].lbl.setText(API.buttons[button].txt)
    end
  else
    if aGroup then
      for d in pairs(API.groups[groupN]) do
        API.buttons[API.groups[groupN][d]].lbl.setText(label)
      end
    else
      API.buttons[button].lbl.setText(label)
    end
  end
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
