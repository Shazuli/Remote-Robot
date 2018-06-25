local API = {}

--[[
local grid1 = {
  {{"X"},{"X"},{"O"}},
  {{"O"},{"O"},{"O"}},
  {{"X"},{"X"},{"X"}}
}
local grid1 = {
  {"X","X","O"},
  {"O","O","O"},
  {"X","O","X"}
}
--]]

API.TCW = {
  {0,-1},
  {1,0}
}

API.TACW = {
  {0,1},
  {-1,0}
}
local function createEmptyMatrix(len)
  local m = {}
  for i=1,len do
    table.insert(m,{})
  end
  return m
end

function API.transpose(matrix,dir)
  local m = createEmptyMatrix(#matrix)
  if dir == 1 then
    for i in pairs(matrix) do
      for d in pairs(matrix[i]) do
        local temp = matrix[i][d]
        m[d][i] = temp
      end
    end
  else

  end
  return m
end

function API.rotate(pos,dir)
  local x,y,z = table.unpack(pos)
  --print("Old Pos: ",x,y,z)
  local newBlockPos = {dir[1][1]*x + dir[1][2]*z, y, dir[2][1]*x + dir[2][2]*z}
  x,y,z = table.unpack(newBlockPos)

  --print("New Pos: ",x,y,z)
  return x,y,z
end

return API
