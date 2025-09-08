local avatar = require('avatar')

return function(opts)
  opts = opts or {}
  local cooldown = opts.cooldown or 0.2
  return {
    channel = 'actor',
    kind = 'mount',
    on = function(self, who, ctx, input, dt)
      self._cd = math.max(0, (self._cd or 0) - (dt or 0))
      if self._cd > 0 then return end
      if not who or not who.player then return end
      if input.pressed('return') then
        if who.collectable and who.collectable.persistent and who.collectable.name == 'driver' then
          who.collectable = nil
        else
          who.collectable = { name = 'driver', value = 0, persistent = true }
        end
        -- Mark changed in tiny by re-adding entity if world/add exists
        if ctx and ctx.world and ctx.world.add then ctx.world:add(who) end
        self._cd = cooldown
      end
    end
  }
end
