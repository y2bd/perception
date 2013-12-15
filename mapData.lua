local Button = require('button')

local FILENAME = "assets/map.png"

local MapData = {}

local signs =
{
  [table.concat({0,0,255},'-')] = "movement is straightforward.",
  [table.concat({0,255,128}, '-')] = "similar things look different up close.",
  [table.concat({55,150,255}, '-')] = "everything looks different in retrospective.",
  [table.concat({200,255,0}, '-')] = "you can only go back so far.",
  [table.concat({128,0,255}, '-')] = "if you don't know where you're going, you won't know when you get there"
}

MapData.Tiles =
{
  SPACE = 0,
  WALL = 1,
  PLAYER = 2,
  GATE = 3
}

local Tiles = MapData.Tiles

local function isWall(r, g, b)
  return r == 255 and g == 153 and b == 0
end

local function isPlayer(r, g, b)
  return r == 255 and g == 0 and b == 0
end

local function isSign(r,g,b)
  return signs[table.concat({r,g,b}, '-')]  
end

local function isGate1(r,g,b)
  return r==255 and g==0 and b==255
end

local function isButton1(r,g,b)
  return r==30 and g==180 and b==90
end

function MapData.loadImageData()
  local imageData = love.image.newImageData(FILENAME)

  return imageData
end

function MapData.getMapData(imageData, blockSize)
  local w = imageData:getWidth()
  local h = imageData:getHeight()

  local map = {}
  local entities = {signs={}, gates={}, buttons={}}

  for r=0,h-1 do
    map[r+1] = {}

    for c=0,w-1 do
      local cr,cg,cb = imageData:getPixel(c, r)

      map[r+1][c+1] = Tiles.SPACE

      local sign = isSign(cr,cg,cb)

      if sign ~= nil then
        table.insert(entities.signs, {r+1, c+1, sign})

      elseif isGate1(cr,cg,cb) then
        map[r+1][c+1] = Tiles.GATE
        if entities.gates[1] == nil then entities.gates[1] = {true, 2, {}} end
        table.insert(entities.gates[1][3], {r+1, c+1})

      elseif isButton1(cr,cg,cb) then
        table.insert(entities.buttons, Button:new(c*blockSize, r*blockSize, blockSize, 1))

      elseif isPlayer(cr,cg,cb) then
        entities['player'] = {r+1, c+1}
      elseif isWall(cr,cg,cb) then
        map[r+1][c+1] = Tiles.WALL
      end

    end
  end

  return map, entities
end


return MapData
