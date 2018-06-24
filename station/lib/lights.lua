local component = require("component")
local API = {}


--[[print(light_boards[1])
print(light_boards[2])
print(light_boards[3])
print(light_boards[4])--]]

function API.clear(boards)
  for i=1,4 do
    for d=1,4 do
      component.proxy(boards[i]).setActive(d,false)
    end
  end
end

local function points(points,boards)
  --[[for i in pairs(points) do
    board.setActive(points[i],true)
  end--]]
  for board in pairs(points) do
    for row in pairs(points[board]) do
      if points[board][row] == 1 then
        component.proxy(boards[board]).setActive(row,true)
      end
    end
  end
  --component.proxy(light_boards[3]).setActive(1,true)
end

function API.digit(number,boards,color)
  API.clear(boards)
  for i=1,4 do
    for d=1,3 do
      component.proxy(boards[i]).setColor(d,color)
    end
  end
  if number == 0 then
    points({
      {1,1,1},
      {1,0,1},
      {1,0,1},
      {1,1,1}},boards)
  elseif number == 1 then
    points({
      {0,0,1},
      {0,0,1},
      {0,0,1},
      {0,0,1}},boards)
  elseif number == 2 then
    points({
      {1,1,1},
      {0,0,1},
      {0,1},
      {1,1,1}},boards)
  elseif number == 3 then
    points({
      {1,1,1},
      {0,0,1},
      {0,1,1},
      {1,1,1}},boards)
  elseif number == 4 then
    points({
      {1,0,1},
      {1,1,1},
      {0,0,1},
      {0,0,1}},boards)
  elseif number == 5 then
    points({
      {1,1,1},
      {1,0,0},
      {0,1},
      {1,1,1}},boards)
  elseif number == 6 then
    points({
      {1,1,1},
      {1},
      {1,1,1},
      {1,1,1}},boards)
  elseif number == 7 then
    points({
      {1,1,1},
      {0,0,1},
      {0,0,1},
      {0,0,1}},boards)
  elseif number == 8 then
    points({
      {1,1,1},
      {1,1,1},
      {1,0,1},
      {1,1,1}},boards)
  elseif number == 9 then
    points({
      {1,1,1},
      {1,1,1},
      {0,0,1},
      {1,1,1}},boards)
  elseif number == 10 then
    points({
      {1,1,1},
      {1,0,1},
      {1,0,1},
      {1,1,1,1}},boards)
  elseif number == 11 then
    points({
      {0,0,1},
      {0,0,1},
      {0,0,1},
      {0,0,1,1}},boards)
  elseif number == 12 then
    points({
      {1,1,1},
      {0,0,1},
      {0,1},
      {1,1,1,1}},boards)
  elseif number == 13 then
    points({
      {1,1,1},
      {0,0,1},
      {0,1,1},
      {1,1,1,1}},boards)
  elseif number == 14 then
    points({
      {1,0,1},
      {1,1,1},
      {0,0,1},
      {0,0,1,1}},boards)
  elseif number == 15 then
    points({
      {1,1,1},
      {1,0,0},
      {0,1},
      {1,1,1,1}},boards)
  elseif number == 16 then
    points({
      {1,1,1},
      {1},
      {1,1,1},
      {1,1,1,1}},boards)
  end
end

return API
