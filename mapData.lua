local FILENAME = "assets/map.png"

local MapData = {}

MapData.Tiles =
{
  SPACE = 0,
  WALL = 1,
  PLAYER = 2
}

local Tiles = MapData.Tiles

local function isWall(r, g, b)
  return r == 255 and g == 153 and b == 0
end

local function isPlayer(r, g, b)
  return r == 255 and g == 0 and b == 0
end

function MapData.loadImageData()
  local imageData = love.image.newImageData(FILENAME)

  return imageData
end

function MapData.getMapData(imageData)
  local w = imageData:getWidth()
  local h = imageData:getHeight()

  local map = {}
  local entities = {}

  for r=0,h-1 do
    map[r+1] = {}

    for c=0,w-1 do
      local cr,cg,cb = imageData:getPixel(c, r)

      map[r+1][c+1] = Tiles.SPACE

      if isPlayer(cr,cg,cb) then
        map[r+1][c+1] = Tiles.SPACE
        entities['player'] = {r+1, c+1}
      elseif isWall(cr,cg,cb) then
        map[r+1][c+1] = Tiles.WALL
      end

    end
  end

  return map, entities
end


return MapData
