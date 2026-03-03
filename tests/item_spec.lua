local file = require('new-item.items').file
local util = require('new-item.util')

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
      extra_args = {
        foo = { complete = function() end },
      },
      before_create = function(this, _) this.label = 'bar' end,
    }
  end)

  it('item:override', function()
    local new_item = item:override(function(final, prev)
      final.default_name = 'bar'
      final.label = prev.label:upper()
      final.extra_args.bar = { complete = function() end }
    end)

    local old_id = util.get_item_uid(item)
    local new_id = util.get_item_uid(new_item)

    assert.are_equal(item, new_item)
    assert.are_equal(new_id, old_id)
    assert.are_equal(item.default_name, 'bar')
    assert.are_equal(item.default_name, 'bar')
    assert.are_equal(item.label, 'FOO')
    assert.are_same({ 'foo', 'bar' }, vim.tbl_keys(util._completions[new_id]))
    assert.are_equal(file, getmetatable(item))
    assert.are_equal(file, getmetatable(new_item))
  end)

  it('item:invoke() does not affect original item', function()
    item:invoke()
    assert.are_equal('foo', item.label)
  end)
end)
