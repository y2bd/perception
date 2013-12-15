local Button = {}

function Button:new(startx, starty, size, gateNum)
  local b = {} 
  b.x = startx
  b.y = starty
  b.size = size
  b.gateNum = gateNum
  b.enabled = false

  self.__index = self
  return setmetatable(b, self)
end

function Button:isColliding(px, py)
  if px < self.x or px > (self.x+self.size) then
    return false
  end

  if py < self.y or py > (self.y+self.size) then
    return false
  end

  return true
end

return Button
