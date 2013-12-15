-- imports
Player = require('player')
MapData = require('mapData')
Camera = require('camera')

-- aliases
local Tiles = MapData.Tiles
local keydown = love.keyboard.isDown
local States = Player.States

-- constants
LIGHT_ANGLE = math.rad(35)
MAX_LIGHT_LENGTH = 1280 -- this really should be dynamically determined
CONE_PRECISION = 256 -- how many points along the light cone do we calculate
MAX_LIGHT_GHOSTS = 1
BLOCK_SIZE = 32
ROT_RAD_PER_SEC = math.rad(90)
CAMERA_EASE = 8

-- local vars
local theta = 0

local polygons =
{
  {{720, 200}, {780, 280}, {860, 200}, {780, 120}},
  {{600, 400}, {630, 420}, {660, 440}, {620, 420}}
}

local mapPolys = {}

local gatePolys = {}

local propellerPolys = {}

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

  local allPolys = {}

  for _,p in ipairs(mapPolys) do
    table.insert(allPolys, p)
  end

  for _,gateLine in ipairs(gatePolys) do
    for _,gate in ipairs(gateLine) do
      table.insert(allPolys, gate)
    end
  end

  for _,prop in ipairs(propellerPolys) do
    table.insert(allPolys, prop)
  end

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

    for _,poly in ipairs(allPolys) do
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

local function generateGatePoly(x, y, orientation)
  -- 1 = horizontal, 2 = vertical
  
  if orientation == 1 then
    return {{x, y + BLOCK_SIZE/4}, {x+BLOCK_SIZE, y+BLOCK_SIZE/4}, {x+BLOCK_SIZE, y+3*BLOCK_SIZE/4}, {x, y+3*BLOCK_SIZE/4}}
  elseif orientation == 2 then
    return {{x + BLOCK_SIZE/4, y}, {x+BLOCK_SIZE/4, y+BLOCK_SIZE}, {x+3*BLOCK_SIZE/4, y+BLOCK_SIZE}, {x+3*BLOCK_SIZE/4, y}}
  end
end

local function generatePropellerPoly(x, y)
  -- wing length
  local wl = BLOCK_SIZE * 2

  --side length
  local sl = BLOCK_SIZE
  
  return 
  {
    {x, y},
    {x, y-wl},
    {x+sl, y-wl},
    {x+sl, y},
    {x+sl+wl, y},
    {x+sl+wl, y+sl},
    {x+sl, y+sl},
    {x+sl, y+sl+wl},
    {x, y+sl+wl},
    {x, y+sl},
    {x-wl, y+sl},
    {x-wl, y}
  }
end

local function rotatePropellers(dt)
  local dtheta = ROT_RAD_PER_SEC

  for i, prop in ipairs(propellerPolys) do
    local cx = (entities.propellers[i][2] - 1) * BLOCK_SIZE + BLOCK_SIZE / 2
    local cy = (entities.propellers[i][1] - 1) * BLOCK_SIZE + BLOCK_SIZE / 1

    for _, point in ipairs(prop) do
      local ox = point[1] - cx
      local oy = point[2] - cy

      local rx = ox * math.cos(dtheta * dt) - oy * math.sin(dtheta * dt)
      local ry = ox * math.sin(dtheta * dt) + oy * math.cos(dtheta * dt)

      point[1] = cx + rx
      point[2] = cy + ry
    end
  end
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

  for i,gateLine in ipairs(entities.gates) do
    print(i)
    print(#(gateLine[3]))
    gatePolys[i] = {}
    for j,gate in ipairs(gateLine[3]) do
      gatePolys[i][j] = generateGatePoly((gate[2]-1)*s, (gate[1]-1)*s, gateLine[2])
    end
  end

  for i,propeller in ipairs(entities.propellers) do
    propellerPolys[i] = generatePropellerPoly((propeller[2]-1)*s, (propeller[1]-1)*s)
  end
end

local function mapLocationToRows(x, y)
  return math.floor(math.ceil(y) / BLOCK_SIZE) + 1, math.floor(math.ceil(x) / BLOCK_SIZE) + 1
end

local function collideWithMoveGate(player, moveGate)
  local gx, gy = (moveGate[2] - 1) * BLOCK_SIZE, (moveGate[1] - 1) * BLOCK_SIZE

  if player.x < gx or player.x > gx + BLOCK_SIZE then
    return false
  end

  if player.y < gy or player.y > gy + BLOCK_SIZE then
    return false
  end
  
  return true 
end

function love.load()
  win = {width = love.graphics.getWidth(), height = love.graphics.getHeight()}

  local id = MapData.loadImageData()
  map, entities = MapData.getMapData(id, BLOCK_SIZE)
  generateMapPolys()

  for _,b in pairs(entities.buttons) do
    if b == nil then
      print ("button "..tostring(_).." is nil")
    else
      print ("button "..tostring(b.gateNum).." "..tostring(b.x).." "..tostring(b.y))
    end
  end

  player = Player:new((entities['player'][2]-1) * 32, (entities['player'][1]-1) * 32)

  Camera:moveTo(player.x - win.width/2, player.y - win.height/2)

  -- muh minimalism
  love.graphics.setColor(255,255,255)
  love.graphics.setLineWidth(2)
  love.graphics.setLineStyle("smooth")
end

function love.update(dt)
  local mx, my = Camera:getMousePosition()

  theta = math.atan2(my - player.y, mx - player.x)

  if player.state == States.STANDING or player.state == States.WALKING then
    if keydown("a", "left") then
      player.vx = -Player.WALKING_VELOCITY
      player.state = States.WALKING
    elseif keydown("d", "right") then
      player.vx = Player.WALKING_VELOCITY 
      player.state = States.WALKING
    else
      player.vx = 0
    end

    if keydown("w", "up") then
      player.vy = -Player.WALKING_VELOCITY
      player.state = States.WALKING
    elseif keydown("s", "down") then
      player.vy = Player.WALKING_VELOCITY
      player.state = States.WALKING
    else
      player.vy = 0
    end

    if player.vx == 0 and player.vy == 0 then
      player.state = States.STANDING
    end
  end

  local r, c = mapLocationToRows(player.x + player.vx*dt, player.y + player.vy * dt)

  if player.state == States.WALKING then
    if player.vx > 0 and (map[r][c+1] ~= Tiles.SPACE or (map[r+1][c+1] ~= Tiles.SPACE and math.floor(player.y % BLOCK_SIZE) ~= 0)) then
      player.vx = 0
    elseif player.vx < 0 and (map[r][c] ~= Tiles.SPACE or (map[r+1][c] ~= Tiles.SPACE and math.floor(player.y % BLOCK_SIZE) ~= 0)) then
      player.vx = 0
    end

    if player.vy > 0 and (map[r+1][c] ~= Tiles.SPACE or (map[r+1][c+1] ~= Tiles.SPACE and math.floor(player.x % BLOCK_SIZE) ~= 0)) then
      player.vy = 0
    elseif player.vy < 0 and (map[r][c] ~= Tiles.SPACE or (map[r][c+1] ~= Tiles.SPACE and math.floor(player.x % BLOCK_SIZE) ~= 0)) then
      player.vy = 0
    end

  end 

  if player.state == States.FALLING then
    if keydown("a", "left") then
      player.vx = -Player.WALKING_VELOCITY / 10
    elseif keydown("d", "right") then
      player.vx = Player.WALKING_VELOCITY / 10
    end

    player.vx = player.vx / 2
  end

  player:update(dt)

  for i,button in pairs(entities.buttons) do
    if button ~= nil and (button.enabled ~= true) and button:isColliding(player.x + BLOCK_SIZE/2, player.y + BLOCK_SIZE/2) then
      button.enabled = true

      local n = button.gateNum

      local oldGates = entities.gates[n]

      print("removing "..tostring(n))
      entities.gates[n] = {}
      gatePolys[n] = {}

      for _,og in ipairs(oldGates[3]) do
        map[og[1]][og[2]] = Tiles.SPACE
      end
    end
  end

  for _,fg in ipairs(entities.fallgates) do
    if player.state ~= Player.States.FALLING and collideWithMoveGate(player, fg) then
      player.state = Player.States.FALLING
      player.vy = 30
    end
  end

  for _,wg in ipairs(entities.walkgates) do
    if collideWithMoveGate(player, wg) then
      player.state = Player.States.WALKING
    end
  end

  rotatePropellers(dt)

  local tx, ty = Camera:resolvePosition(player.x, player.y)

  --[[
  if tx < (win.width * 2 / 5) or tx > (win.width * 3 / 5) then
    Camera:move(player.vx * dt, nil)
  end

  if ty < (win.height * 2 / 5) or ty > (win.height * 3 / 5) then
    Camera:move(nil, player.vy * dt)
  end
  --]]
  
  if tx < (win.width * 3 / 7) then
    local diff = (win.width * 3 / 7) - tx
    Camera:move(- diff / CAMERA_EASE, nil)
  end

  if tx > (win.width * 4 / 7) then
    local diff = (win.width * 4 / 7) - tx
    Camera:move(- diff / CAMERA_EASE, nil)
  end

  if ty < (win.height * 3 / 7) then
    local diff = (win.height * 3 / 7) - ty
    Camera:move(nil, - diff / CAMERA_EASE)
  end

  if ty > (win.height * 4 / 7) then
    local diff = (win.height * 4 / 7) - ty
    Camera:move(nil, - diff / CAMERA_EASE)
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

  love.graphics.print(love.timer.getFPS(), 20, 20)

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

  love.graphics.setColor(0,0,0)
  for _,sign in ipairs(entities.signs) do
    love.graphics.print(sign[3], (sign[2]-1) * BLOCK_SIZE, (sign[1]-1) * BLOCK_SIZE)
  end

  for _,button in pairs(entities.buttons) do
    if button ~= nil then
      local fillMode = button.enabled and "line" or "fill"

      love.graphics.rectangle(fillMode, button.x + button.size/4, button.y + button.size/4, button.size/2, button.size/2)
    end
  end

  --love.graphics.setColor(0,0,255)
  --love.graphics.rectangle('fill', player.x, player.y, BLOCK_SIZE, BLOCK_SIZE)

  Camera:unset()
end

