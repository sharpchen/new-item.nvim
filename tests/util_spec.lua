local util = require('new-item.util')

describe('util', function()
  it('make_switch', function()
    local switch = util.make_switch {
      {
        cond = function(input) return input == 2 end,
        action = function(input) return input * input end,
      },
      {
        cond = function(input) return input < 5 end,
        action = function(input) return input end,
      },
    }

    local outputs = switch { 1, 2, 3, 4, 5 }
    assert.are_same({ 1, 4, 3, 4 }, outputs)
  end)
end)
