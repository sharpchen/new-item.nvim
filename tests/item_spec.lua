local file = require('new-item.items').file

describe('Item', function()
  ---@type new-item.Item
  local item

  before_each(function()
    item = file {
      __test = true,
      content = 'foo',
      nameable = false,
      default_name = 'foo',
      label = 'foo',
      before_create = function(this, _) this.label = 'bar' end,
    }
  end)

  it('item:override', function()
    item:override(function(final, prev)
      final.default_name = 'bar'
      final.label = prev.label:upper()
    end)

    assert.are_equal(item.default_name, 'bar')
    assert.are_equal(item.label, 'FOO')
    assert.are_equal(file, getmetatable(item))
  end)

  it('item:invoke() does not affect original item', function()
    item:invoke()
    assert.are_equal('foo', item.label)
  end)
end)
