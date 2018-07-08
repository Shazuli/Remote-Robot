local c = require("component")
local u = require("unicode")
local gpu = c.gpu
local API = {}

function API.SetGPU(newGPU)
  if newGPU == nil then return end
  local result = pcall(function()
    gpu = newGPU
  end)
  return result
end

function API.fillRect(x,y,w,h,color)
  local background = gpu.getBackground()
  local result = pcall(function()
    gpu.setBackground(color)
    gpu.fill(x,y,w,h," ")
    gpu.setBackground(background)
  end)
  return result
end

function API.addFloatingText(x,y,txt)
  local background = gpu.getBackground()
  local result = pcall(function()
    if type(txt) == "table" then
      for i in pairs(txt) do
        for d=1,u.len(txt[i]) do
          local _,_,g = gpu.get(x+d-1,y)
          local k = u.sub(txt[i],d,d)
          gpu.setBackground(g)
          gpu.set(x+d-1,y+i,k)
        end
      end
      gpu.setBackground(background)
    else
      for d=1,u.len(txt) do
        local _,_,g = gpu.get(x+d-1,y)
        local k = u.sub(txt,d,d)
        gpu.setBackground(g)
        gpu.set(x+d-1,y,k)
        gpu.setBackground(background)
      end
    end
  end)
  return result
end

function API.addText(x,y,txt,color)
  local background = gpu.getBackground()
  local result = pcall(function()
    if type(txt) == "table" then
      local g = background
      if color then
        g = color
      else
        _,_,g = gpu.get(x,y)
      end
      for i in pairs(txt) do
        gpu.setBackground(g)
        gpu.set(x,y+i,txt[i])
      end
      gpu.setBackground(background)
    else
      if color then
        g = color
      else
        _,_,g = gpu.get(x,y)
      end
      gpu.setBackground(g)
      gpu.set(x,y,txt)
      gpu.setBackground(background)
    end
  end)
  return result
end

return API
