local Player = {}

Player.WALKING_VELOCITY = 120
Player.GRAVITY = 250

Player.States = 
{
  STANDING = 0,
  WALKING = 1,
  FALLING = 2
}

function Player:new(startx, starty)
  local p =
  {
    x = startx,
    y = starty,
    vx = 0,
    vy = 0,
    state = Player.States.STANDING
  }

  self.__index = self
  return setmetatable(p, self)
end

function Player:update(dt)
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt

  if self.state == Player.States.FALLING then
    self.vy = self.vy + Player.GRAVITY * dt
    self.y = self.y + self.vy * dt
  end
end

function Player:draw()
   
end

return Player
