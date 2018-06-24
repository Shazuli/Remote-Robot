local API = {}

function API.transpose(m)
   local rotated = {}
   for c, m_1_c in ipairs(m[1]) do
      local col = {m_1_c}
      for r = 2, #m do
         col[r] = m[r][c]
      end
      table.insert(rotated, col)
   end
   return rotated
end
function API.rotate_CCW_90(m)
   local rotated = {}
   for c, m_1_c in ipairs(m[1]) do
      local col = {m_1_c}
      for r = 2, #m do
         col[r] = m[r][c]
      end
      table.insert(rotated, 1, col)
   end
   return rotated
end

local function transpose()

end

function API.rotate90(grid)
  local t = {}
  for i in pairs(grid) do
    for d in pairs(grid) do

    end
  end
  return t
end

function API.rotate_CW_90(m)
   return API.rotate_CCW_90(API.rotate_CCW_90(API.rotate_CCW_90(m)))
end
return API
