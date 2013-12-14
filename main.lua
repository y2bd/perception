LIGHT_ANGLE = math.rad(30)
MAX_LIGHT_LENGTH = 640 -- this really should be dynamically determined
CONE_PRECISION = 96 -- how many points along the light cone do we calculate

local theta = 0

local polygons =
{
  {{720, 200}, {780, 280}, {860, 200}, {780, 120}},
  {{600, 400}, {630, 420}, {660, 440}, {620, 420}}
}

local endpoint = {0, 0}

local intersecting = false

local function getLight()
  -- vertices
  local vs = {}

  vs[#vs+1] = win.width / 2
  vs[#vs+1] = win.height / 2

  local leftAng = theta - LIGHT_ANGLE / 2

  --[
  -- We're adding the points of the light (triangle for now)
  -- First you add the x coordinate, then the y coordinate
  --]
  vs[#vs+1] = win.width / 2 + MAX_LIGHT_LENGTH * math.cos(leftAng)
  vs[#vs+1] = win.height / 2 + MAX_LIGHT_LENGTH * math.sin(leftAng)

  local rightAng = theta + LIGHT_ANGLE / 2

  vs[#vs+1] = win.width / 2 + MAX_LIGHT_LENGTH * math.cos(rightAng)
  vs[#vs+1] = win.height / 2 + MAX_LIGHT_LENGTH * math.sin(rightAng)

  return vs
end

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

local function getLightCone()
  -- vertices
  local vs = {win.width / 2, win.height / 2}

  for i = 1, CONE_PRECISION do
    local angle = (theta - LIGHT_ANGLE/2) + (i-1) * LIGHT_ANGLE / (CONE_PRECISION - 1)
    
    local startpoint =
    {
      win.width / 2,
      win.height / 2,
    }

    local endpoint =
    {
      win.width / 2 + MAX_LIGHT_LENGTH * math.cos(angle),
      win.height / 2 + MAX_LIGHT_LENGTH * math.sin(angle)
    }

    for _,poly in ipairs(polygons) do
      for vi=1, #poly do
        local endIndex = vi < #poly and vi + 1 or 1

        local intersection = intersect(startpoint, endpoint, poly[vi], poly[endIndex])

        if intersection ~= nil and disSquared(startpoint, intersection) < disSquared(startpoint, endpoint) then
          endpoint = intersection
        end
      end
    end

    vs[#vs+1] = endpoint[1]
    vs[#vs+1] = endpoint[2]
  end

  return vs
end

function love.load()
  win = {width = love.graphics.getWidth(), height = love.graphics.getHeight()}

  -- muh minimalism
  love.graphics.setColor(255,255,255)
  love.graphics.setLineWidth(2)
  love.graphics.setLineStyle("smooth")
end

function love.update(dt)
  local mx = love.mouse.getX()
  local my = love.mouse.getY()

  theta = math.atan2(my - win.height/2, mx - win.width/2)
  theta = clamp(theta, math.rad(-80), math.rad(80))

  endpoint[1] = win.width / 2 + MAX_LIGHT_LENGTH * math.cos(theta)
  endpoint[2] = win.height / 2 + MAX_LIGHT_LENGTH * math.sin(theta)

  intersection = intersect({win.width / 2, win.height / 2}, endpoint, {720, 200}, {780, 280})

  if intersection ~= nil then
    endpoint[1] = intersection[1]
    endpoint[2] = intersection[2]
    intersecting = true
  else
    intersecting = false
  end
end

function love.draw()
  --love.graphics.setColor(255,255,255)
  love.graphics.print(theta, win.width/2, win.height/2)

  --love.graphics.polygon('fill', getLight())
  --[[
  triangles = love.math.triangulate(getLightCone())

  for _,t in ipairs(triangles) do
    love.graphics.polygon('line', t)
  end
  --love.graphics.line(win.width / 2, win.height / 2, endpoint[1], endpoint[2])
  --love.graphics.line(720, 200, 780, 280)
  --]]

  love.graphics.polygon('line', getLightCone())

  if intersecting then 
    --love.graphics.print("INTERSECTING", 0, 0)
  end

  love.graphics.print(t, 0, 20)
  love.graphics.print(u, 0, 40)

  --love.graphics.setColor(255,0,0)
  --love.graphics.polygon('fill', {720, 200, 780, 280, 860, 200, 780, 120})

end

