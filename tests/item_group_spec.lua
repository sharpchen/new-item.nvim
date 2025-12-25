local file = require('new-item.items').file

describe('ItemGroup', function()
  ---@type new-item.ItemGroup
  local group

  before_each(function()
    group = require('new-item.items.item_group'):new {
      visible = true,
      sources = {
        {
          name = 'test1',
          function() return { file {}, file {}, file {}, file {} } end,
        },
        {
          name = 'test2',
          function() return { file {}, file {} } end,
        },
        {
          name = 'test3',
          function() return { file {}, file {}, file {}, file {} } end,
        },
      },
      items = { file {}, file {} },
    }
    group:append { file {}, file {} }
    group:remove_source { 'test3' }
    group:load_sources()
  end)

  it('iter_items', function()
    local count = 0

    for _ in group:iter_items() do
      count = count + 1
    end

    assert.are.equal(10, count)
  end)

  it('get_items', function() assert.are.equal(10, #group:get_items()) end)
  it('override', function() end)
end)
