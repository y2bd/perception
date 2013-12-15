local Camera =
{
  x = 0,
  y = 0
}

function Camera:set()
  -- push our transformation onto the stack for drawing
  love.graphics.push()

  love.graphics.translate(-self.x, -self.y)
end

function Camera:unset()
  -- take off the stack for updating
  love.graphics.pop()
end

function Camera:move(dx, dy)
  self.x = self.x + (dx or 0)
  self.y = self.y + (dy or 0)
end

function Camera:moveTo(x, y)
  self.x = x or self.x
  self.y = y or self.y
end

-- necessary because shifing everything makes mouse position invalid
function Camera:getMousePosition()
  return self:resolvePosition(love.mouse.getX(), love.mouse.getY())
end

-- converts an absolute position to a camera-transformed one
function Camera:resolvePosition(x, y)
  return x + self.x, y + self.y
end

return Camera

