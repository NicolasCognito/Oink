-- Resolve local libs and src paths (tiny-ecs lives in libs)
local function setup_require_path()
  local extra = table.concat({
    'src/?.lua','src/?/init.lua',
    'libs/?.lua','libs/?/init.lua',
    'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  }, ';')
  if love and love.filesystem and love.filesystem.setRequirePath then
    local req = love.filesystem.getRequirePath()
    love.filesystem.setRequirePath((req and #req>0 and (req..';') or '') .. extra)
  else
    package.path = package.path .. ';' .. extra
  end
end

local Game

function love.load()
  setup_require_path()
  Game = require('game')
  Game.load()
end

function love.update(dt)
  Game.update(dt)
end

function love.draw()
  Game.draw()
end
