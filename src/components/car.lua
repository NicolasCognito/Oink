local match = require('entity_match')
local Inventory = require('inventory')
local H_vehicle = require('input.handlers.vehicle')
local H_inventory = require('input.handlers.inventory')

local function new_car(opts)
  opts = opts or {}
  local e = {
    agent = true,
    car = true,
    collector = true,
    label = opts.label or 'Car',
    drawable = true,
    pos = { x = opts.x or 200, y = opts.y or 200 },
    vel = { x = 0, y = 0 },
    radius = opts.radius or 10,
    inventory = Inventory.new(1), -- only first slot used
    heading = opts.heading or 0,
  }
  -- Slot 1 accepts only drivers
  Inventory.define_slot(e.inventory, 1, {
    default_name = 'driver',
    accept = function(_, item) return item and item.driver == true end,
  })
  -- Collector policy: accept items that are both collectable and driver
  e.collect_query = match.build_query({
    whitelist = function(_, it)
      return it and it.collectable and it.driver == true
    end
  })
  -- Handlers are attached centrally by input profiles based on components
  -- Draw: implement non-generic visuals here (arrow showing heading/movement)
  function e:draw(gfx, ctx)
    local x, y = self.pos.x or 0, self.pos.y or 0
    local r = self.radius or 10
    -- Body
    if self.color then gfx.setColor(self.color) else gfx.setColor(0.8,0.8,0.9,1) end
    gfx.circle('fill', x, y, r)
    gfx.setColor(1,1,1,1)
    -- Arrow
    local dirx, diry
    if self.heading ~= nil then
      dirx, diry = math.cos(self.heading), math.sin(self.heading)
    elseif self.vel and (self.vel.x ~= 0 or self.vel.y ~= 0) then
      local vx, vy = self.vel.x, self.vel.y
      local mag = math.sqrt(vx*vx + vy*vy)
      if mag > 0 then dirx, diry = vx/mag, vy/mag else return end
    else
      return
    end
    local len = r * 2.0
    local tipx, tipy = x + dirx * len, y + diry * len
    local perp_x, perp_y = -diry, dirx
    local backx, backy = x + dirx * (len - r * 0.6), y + diry * (len - r * 0.6)
    local wamt = r * 0.7
    local w1x, w1y = backx + perp_x * wamt, backy + perp_y * wamt
    local w2x, w2y = backx - perp_x * wamt, backy - perp_y * wamt
    local oldw = (gfx.getLineWidth and gfx.getLineWidth()) or 1
    gfx.setLineWidth(2)
    gfx.line(x, y, tipx, tipy)
    gfx.line(tipx, tipy, w1x, w1y)
    gfx.line(tipx, tipy, w2x, w2y)
    gfx.setLineWidth(oldw)
    gfx.setColor(1,1,1,1)
  end
  return e
end

return { new = new_car }
