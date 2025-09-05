package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local match = require('entity_match')

describe('entity_match policy', function()
  it('accepts by whitelist function and respects blacklist', function()
    local c = { id = 1 }
    local coin = { collectable = { name='coin' } }
    local mine = { collectable = { name='work' } }
    local ctx = {}
    local policy = {
      whitelist = function(_, it) return it.collectable and it.collectable.name == 'coin' end,
      blacklist = function(_, it) return it.collectable and it.collectable.name == 'work' end,
    }
    assert.is_true(match.match_policy(c, coin, ctx, policy))
    assert.is_false(match.match_policy(c, mine, ctx, policy))
  end)

  it('supports structured any_of/all_of/none_of and where', function()
    local c = {}
    local passenger = { collectable=true, passenger=true }
    local operator  = { collectable=true, operator=true }
    local ctx = { seat_free = true }
    local policy = {
      whitelist = { all_of={'collectable'}, any_of={'passenger'}, where=function(_, _, _) return true end },
      blacklist = { any_of={'operator'} },
    }
    assert.is_true(match.match_policy(c, passenger, ctx, policy))
    assert.is_false(match.match_policy(c, operator, ctx, policy))
  end)

  it('defaults to accept when whitelist is empty, unless blacklisted', function()
    local c = {}
    local item = { x = 1 }
    local ctx = {}
    local policy = { blacklist = function(_, it) return it.x == 2 end }
    assert.is_true(match.match_policy(c, item, ctx, policy))
    item.x = 2
    assert.is_false(match.match_policy(c, item, ctx, policy))
  end)

  it('build_query returns only matching items', function()
    local c = {}
    local ctx = { collectables = {
      { collectable={ name='coin' } },
      { collectable={ name='work' } },
    }}
    local policy = { whitelist = function(_, it) return it.collectable and it.collectable.name == 'coin' end }
    local q = match.build_query(policy)
    local res = q(c, ctx)
    assert.are.equal(1, #res)
    assert.are.equal('coin', res[1].collectable.name)
  end)
end)

