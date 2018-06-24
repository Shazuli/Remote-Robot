--local g = require("gButtonAPI4")
local u = require("unicode")
local API = {}
local keyNames = {}
local settingsNames = {"caps","off","scale","shift"}

API.caps = false
local shift = false

local function readSettings(x)
  local y = {}
  for i in pairs(x) do
    for _,d in ipairs(settingsNames) do
      if x[i][1] == d then
        y[d] = x[i][2]
      end
    end
  end
  return y
end

local function caps(x,lib)
  if x == "shift" then shift = true end
  API.caps = not API.caps
  if API.caps then
    lib.Color(x,{0,255,0})
    for _,i in ipairs(keyNames) do
      lib.Label(i,lib.buttons[i].customData[2])
    end
  else
    lib.Color(x)
    for _,i in ipairs(keyNames) do
      lib.Label(i,lib.buttons[i].customData[1])
    end
  end
end

function API.initialize(x,y,btns,sett,name,output,lib)
  local settings = readSettings(sett)
  local scale = 1
  local done = {false,false}
  if settings["scale"] ~= nil then
    scale = settings["scale"]
  end
  local offTrue = false
  if settings["off"] ~= nil then
    offTrue = true
  end
  for i in pairs(btns[1]) do
    local o = 0
    if offTrue then
      if i % 2 ~= 0 then o = settings["off"] else o = 0 end
    end
    io.write("[")
    for d=1, u.len(btns[1][i]) do
      local k = u.sub(btns[1][i],d,d)
      local kShift = u.sub(btns[2][i],d,d)
      table.insert(keyNames,k)
      io.write(k)
      lib.createNewButton(k,name,k,x+scale*(o+((d-1)*16)),y+scale*((i-1)*12),scale*15,scale*10,{255,0,0},0.4,function(x)
        lib.Opacity(x,0.8)
        if API.caps then
          output(lib.buttons[k].customData[2])
        else
          output(lib.buttons[k].customData[1])
        end
        if shift then
          API.caps = false
          for _,i in ipairs(keyNames) do
            lib.Label(i,lib.buttons[i].customData[1])
          end
          lib.Color("shift")
          shift = false
        end
        os.sleep(0.5)
        lib.Opacity(x)
      end)
      lib.buttons[k].customData = {k,kShift}
      os.sleep(0)
      if settings["caps"] and settings["caps"] ~= nil then
        if not done[1] and i == 3 then
          lib.createNewButton("caps",name,"CapsLock",x+scale*((d-1)*16)-49,y+scale*((i-1)*12),48,10*scale,{255,0,0},0.4,function(x)
            caps(x,lib) end)
          done[1] = true
        end
      end
      if settings["shift"] and settings["shift"] ~= nil then
        if not done[2] and i == 4 then
          lib.createNewButton("shift",name,"^",x+scale*((d-1)*16)-49+22,y+scale*((i-1)*12),48-22,10*scale,{255,0,0},0.4,function(x)
            caps(x,lib)
          end)
          done[2] = true
        end
      end
    end
    print("] " .. u.len(btns[1][i]))
  end
  --lib.createNewButton("test2","buttons","Test 2",5,25,30,10,{255,0,0},0.8,function() print("Clicked 2.") end) -- could you add another button here ?
  --for _,i in ipairs(lib) do print(i) end
end

return API
