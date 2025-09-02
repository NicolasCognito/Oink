local function new_player(opts)
  opts = opts or {}
  local e = {
    pos = { x = opts.x or 20, y = opts.y or 60 },
    vel = { x = 0, y = 0 },
    speed = opts.speed or 140,
    radius = opts.radius or 6,
    drawable = true,
    controllable = true,
    collector = true,
    player = true,
    score = 0,
    label = opts.label or 'Player',
  }
  return e
end

return {
  new = new_player
}
