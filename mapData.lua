local Button = require('button')

local FILENAME = "assets/map.png"

local MapData = {}

local signs =
{
  [table.concat({0,0,255},'-')] = "movement is straightforward.",
  [table.concat({0,255,128}, '-')] = "similar things look different up close.",
  [table.concat({55,150,255}, '-')] = "everything looks different in retrospective.",
  [table.concat({200,255,0}, '-')] = "you can only go back so far.",
  [table.concat({128,0,255}, '-')] = "if you don't know where you're going, you won't know when you get there.",
  [table.concat({255,225,0}, '-')] = "round",
  [table.concat({200,220,255}, '-')] = "you go",
  [table.concat({80,120,255}, '-')] = "a good memory holds many secrets.",
  [table.concat({80,160,255}, '-')] = "congrats, you found an easter egg in this game of sorts!",
  [table.concat({80,200,255}, '-')] = "i hope you enjoy the rest of it.",
  [table.concat({80,240,255}, '-')] = "and if you were wondering, yes, I loved Antichamber.",
  [table.concat({255,0,50}, '-')] = "wrong.",
  [table.concat({50,255,0}, '-')] = "right.",
  [table.concat({100,70,0}, '-')] = "right and wrong are relative.",
  [table.concat({128,128,128}, '-')] = "some choices matter more than others."
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

local function isGate2(r,g,b)
  return r==0 and g==150 and b==100
end

local function isButton2(r,g,b)
  return r==60 and g==180 and b==180
end

local function isGate3(r,g,b)
  return r==0 and g==180 and b==60
end

local function isButton3(r,g,b)
  return r==0 and g==240 and b==120
end

local function isGate4(r,g,b)
  return r==180 and g==130 and b==60
end

local function isButton4(r,g,b)
  return r==60 and g==130 and b==180
end

local function isGate5(r,g,b)
  return r==230 and g==120 and b==200
end

local function isGate6(r,g,b)
  return r==200 and g==120 and b==230
end

local function isPropeller(r,g,b)
  return r==215 and g==120 and b==215
end

function MapData.loadImageData()
  local imageData = love.image.newImageData(FILENAME)

  return imageData
end

function MapData.getMapData(imageData, blockSize)
  local w = imageData:getWidth()
  local h = imageData:getHeight()

  local map = {}
  local entities = {signs={}, gates={}, buttons={}, propellers={}}

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
        entities.buttons[1] = Button:new(c*blockSize, r*blockSize, blockSize, 1)

      elseif isGate2(cr,cg,cb) then
        map[r+1][c+1] = Tiles.GATE
        if entities.gates[2] == nil then entities.gates[2] = {true, 2, {}} end
        table.insert(entities.gates[2][3], {r+1, c+1})

      elseif isButton2(cr,cg,cb) then
        entities.buttons[2] = Button:new(c*blockSize, r*blockSize, blockSize, 2)

      elseif isGate3(cr,cg,cb) then
        map[r+1][c+1] = Tiles.GATE
        if entities.gates[3] == nil then entities.gates[3] = {true, 2, {}} end
        table.insert(entities.gates[3][3], {r+1, c+1})

      elseif isButton3(cr,cg,cb) then
        entities.buttons[3] = Button:new(c*blockSize, r*blockSize, blockSize, 3)

      elseif isGate4(cr,cg,cb) then
        print("gate4 "..tostring(r+1).." "..tostring(c+1))
        map[r+1][c+1] = Tiles.SPACE
        if entities.gates[4] == nil then entities.gates[4] = {true, 2, {}} end
        table.insert(entities.gates[4][3], {r+1, c+1})

      elseif isButton4(cr,cg,cb) then
        entities.buttons[4] = Button:new(c*blockSize, r*blockSize, blockSize, 4)

      elseif isGate5(cr,cg,cb) then
        map[r+1][c+1] = Tiles.GATE
        if entities.gates[5] == nil then entities.gates[5] = {true, 2, {}} end
        table.insert(entities.gates[5][3], {r+1, c+1})

      elseif isGate6(cr,cg,cb) then
        map[r+1][c+1] = Tiles.GATE
        if entities.gates[6] == nil then entities.gates[6] = {true, 1, {}} end
        table.insert(entities.gates[6][3], {r+1, c+1})

      elseif isPropeller(cr,cg,cb) then
        table.insert(entities.propellers, {r+1, c+1})

      elseif isPlayer(cr,cg,cb) then
        entities['player'] = {r+1, c+1}
      elseif isWall(cr,cg,cb) then
        map[r+1][c+1] = Tiles.WALL
      end

    end
  end

  print ("buttons "..tostring(#(entities.buttons)))

  return map, entities
end


return MapData
