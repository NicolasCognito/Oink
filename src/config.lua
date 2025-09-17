local C = {}

-- World bounds for coin spawning
C.world = {
  width = 800,
  height = 600,
}

-- Spawner config
C.spawner = {
  interval = 0.5, -- spawn twice as often
  max_alive = 120, -- allow more coins alive
  area = { x_min = 0, x_max = 800, y_min = 0, y_max = 600 },
}

-- Collector config
C.collector = {
  base_speed = 140,
  pickup_radius = 8,
  deposit_radius = 8,
}

-- Vault config
C.vault = {
  spawn_cost = 3,
  override_speed = 120,
  spawn_rate_multiplier = 2.0,
}

return C

