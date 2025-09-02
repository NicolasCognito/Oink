local Agent = require('components.agent')

local function new_tax_collector(opts)
  opts = opts or {}
  local e = Agent.new(opts)
  e.collector = true
  e.label = e.label or 'Collector'
  e.color = e.color or {0.2, 0.4, 1.0, 1}
  e.speed = e.speed or 120
  return e
end

return { new = new_tax_collector }

