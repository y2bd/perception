-- imports
Player = require('player')
MapData = require('mapData')
Camera = require('camera')

-- aliases
local Tiles = MapData.Tiles
local keydown = love.keyboard.isDown
local States = Player.States

-- constants
LIGHT_ANGLE = math.rad(25)
MAX_LIGHT_LENGTH = 1280 -- this really should be dynamically determined
CONE_PRECISION = 256 -- how many points along the light cone do we calculate
MAX_LIGHT_GHOSTS = 1
BLOCK_SIZE = 32

-- local vars
local theta = 0

local polygons =
{
  {{720, 200}, {780, 280}, {860, 200}, {780, 120}},
  {{600, 400}, {630, 420}, {660, 440}, {620, 420}}
}

local mapPolys = {}

local player, map, entities

local lightQueue = {}

-- local funcs
local function clamp(val, min, max)
  val = math.min(max, val)
  val = math.max(min, val)

  return val
end

local function isBetween(val, min, max)
  return val >= min and val <= max
end

-- calculates the magnitude of the cross product
local function quickCross(vecV, vecW)
  return vecV[1] * vecW[2] - vecV[2] * vecW[1]
end

-- detects if line segment AB intersects with CD
-- returns the point of intersection if intersects AT ONE POINT
-- otherwise returns nil
--
-- essentially parameterizes two vectors (A + tB, C + uD)
-- and detects whether we can find an r and an s that causes the two vectors
-- to intersect AND stay within the two line segments
-- ( 0 <= r <= 1, 0 <= s <= 1, A + tB = C + uD )
local function intersect(pA, pB, pC, pD)
  local normAB = {pB[1] - pA[1], pB[2] - pA[2]}
  local normCD = {pD[1] - pC[1], pD[2] - pC[2]}

  local crossNorms = quickCross(normAB, normCD)

  local distanceBetweenStarts = {pA[1] - pC[1], pA[2] - pC[2]}

  local crossDisNormAB = quickCross(normAB, distanceBetweenStarts)
  local crossDisNormCD = quickCross(normCD, distanceBetweenStarts)

  t = crossDisNormAB / crossNorms
  u = crossDisNormCD / crossNorms

  if isBetween(t, 0, 1) and isBetween(u, 0, 1) then
    return {pA[1] + u * normAB[1], pA[2] + u * normAB[2]}
  end

  return nil
end

local function disSquared(p1, p2)
  return (p2[1] - p1[1]) ^ 2 + (p2[2] - p1[2]) ^ 2
end

local function getLightCone(emitx, emity)
  -- vertices
  local vs = {emitx, emity}

  for i = 1, CONE_PRECISION do
    local angle = (theta - LIGHT_ANGLE/2) + (i-1) * LIGHT_ANGLE / (CONE_PRECISION - 1)

    local startpoint =
    {
      emitx,
      emity,
    }

    local endpoint =
    {
      emitx + MAX_LIGHT_LENGTH * math.cos(angle),
      emity + MAX_LIGHT_LENGTH * math.sin(angle)
    }

    for _,poly in ipairs(mapPolys) do
      for vi=1, #poly do

        -- if it's too far away don't bother calculating
        if disSquared(startpoint, poly[vi]) < MAX_LIGHT_LENGTH^2 then       

          local endIndex = vi < #poly and vi + 1 or 1

          local intersection = intersect(startpoint, endpoint, poly[vi], poly[endIndex])

          if intersection ~= nil and disSquared(startpoint, intersection) < disSquared(startpoint, endpoint) then
          endpoint = intersection
        end

      end

    end
  end

  vs[#vs+1] = endpoint[1]
  vs[#vs+1] = endpoint[2]
end

return vs
end

local function generateMapPolys()
  local s = BLOCK_SIZE

  for r=1,#map do
    for c=1, #(map[r]) do
      if map[r][c] == Tiles.WALL then
        local x, y = s*(c-1), s*(r-1)
        mapPolys[#mapPolys+1] = {{x, y}, {x+s, y}, {x+s, y+s}, {x, y+s}}
      end
    end
  end
end

local function mapLocationToRows(x, y)
  return math.floor(y / BLOCK_SIZE) + 1, math.floor(x / BLOCK_SIZE) + 1
end

function love.load()
  win = {width = love.graphics.getWidth(), height = love.graphics.getHeight()}

  local id = MapData.loadImageData()
  map, entities = MapData.getMapData(id)
  generateMapPolys()

  player = Player:new((entities['player'][2]-1) * 32, (entities['player'][1]-1) * 32)

  Camera:moveTo(player.x - win.width/2, 0)

  -- muh minimalism
  love.graphics.setColor(255,255,255)
  love.graphics.setLineWidth(2)
  love.graphics.setLineStyle("smooth")
end

function love.update(dt)
  local mx, my = Camera:getMousePosition()

  theta = math.atan2(my - player.y, mx - player.x)

  local r, c = mapLocationToRows(player.x + player.vx*dt, player.y + player.vy * dt)

  if player.state == States.STANDING or player.state == States.WALKING then
    if keydown("a", "left") then
      player.vx = -Player.WALKING_VELOCITY
      player.state = States.WALKING
    elseif keydown("d", "right") then
      player.vx = Player.WALKING_VELOCITY 
      player.state = States.WALKING
    else
      player.vx = 0
      player.state = States.STANDING
    end

    if keydown("w", "up", "space") then
      player.vy = -150
      player.state = States.FALLING
    end

    if map[r+1][c] ~= Tiles.WALL and not (map[r+1][c+1] == Tiles.WALL and player.x % BLOCK_SIZE ~= 0) then
      player.state = States.FALLING
    end
  end
  
  r, c = mapLocationToRows(player.x + player.vx*dt, player.y + player.vy * dt)

  if player.state == States.FALLING then
    if keydown("a", "left") then
      player.vx = -Player.WALKING_VELOCITY
    elseif keydown("d", "right") then
      player.vx = Player.WALKING_VELOCITY 
    end

    if map[r][c] == Tiles.WALL then
      player.vy = 0
    elseif map[r][c+1] == Tiles.WALL and player.x % BLOCK_SIZE ~= 0 then
      -- this is so the player collides with blocks that only half of its head hits
      player.vy = 0
    elseif map[r+1][c] == Tiles.WALL or (map[r+1][c+1] == Tiles.WALL and player.x % BLOCK_SIZE ~= 0) then
      player.vy = 0
      player.vx = 0
      player.state = States.STANDING
    end
  end
  
  r, c = mapLocationToRows(player.x + player.vx*dt, player.y + player.vy * dt)

  if player.state == States.WALKING or player.state == States.FALLING then
    if map[r][c+1] == Tiles.WALL and player.vx > 0 then
      player.vx = 0
    elseif map[r][c] == Tiles.WALL and player.vx < 0 then
      player.vx = 0
    end
  end  

  player:update(dt)

  local tx, ty = Camera:resolvePosition(player.x, player.y)

  if tx < (win.width / 4) or tx > (win.width * 3 / 4) then
    Camera:move(player.vx * dt, nil)
  end
end


function love.draw()
  Camera:set()

  love.graphics.setColor(255,255,255)
  love.graphics.print(theta, win.width/2, win.height/2)

  local triangles = love.math.triangulate(getLightCone(player.x + BLOCK_SIZE/2, player.y + BLOCK_SIZE/2))

  table.insert(lightQueue, triangles)

  if #lightQueue > MAX_LIGHT_GHOSTS then
    table.remove(lightQueue, 1)
  end

  love.graphics.print(love.timer.getFPS(), 0, 0)

  for i,g in ipairs(lightQueue) do
    local opacity = (i) * 255 / MAX_LIGHT_GHOSTS
    love.graphics.setColor(opacity, opacity, opacity)

    for _,t in ipairs(g) do
      love.graphics.polygon('fill', t)
    end
  end
  --love.graphics.line(win.width / 2, win.height / 2, endpoint[1], endpoint[2])
  --love.graphics.line(720, 200, 780, 280)

  --love.graphics.polygon('line', getLightCone(win.width/2, win.height/2))
  love.graphics.setColor(255,0,0)
  --love.graphics.polygon('fill', {720, 200, 780, 280, 860, 200, 780, 120})

  for r=1, #map do
    for c=1, #(map[r]) do
      if map[r][c] == Tiles.WALL then
        --love.graphics.rectangle('fill', (c-1) * 32, (r-1) * 32, 32, 32)
      end
    end
  end

  --love.graphics.setColor(0,0,255)
  --love.graphics.rectangle('fill', player.x, player.y, BLOCK_SIZE, BLOCK_SIZE)

  Camera:unset()
end

