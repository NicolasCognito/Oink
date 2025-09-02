_G.love = _G.love or {}
local function noop() end
love.timer = love.timer or { getTime = function() return 0 end }
love.math = love.math or { random = math.random }
love.graphics = love.graphics or setmetatable({
  print = function() end,
  circle = function() end,
}, { __index = function() return noop end })

