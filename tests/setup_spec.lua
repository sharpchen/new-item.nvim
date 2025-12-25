local file = require('new-item.items').file
local util = require('new-item.util')
local groups = require('new-item.groups')
local ItemGroup = require('new-item.items').ItemGroup

describe('setup', function()
  before_each(function()
    require('new-item').setup {
      groups = {
        dotnet = {
          visible = false,
        },
        gitignore = false, -- disable gitignore
      },
      init = function(groups, items) end,
      transform_path = function(path) return path .. '__foo' end,
    }
  end)

  it('config.groups', function()
    assert(
      vim
        .iter(util.enabled_groups())
        :all(function(group) return group.name and group.name ~= 'gitignore' end)
    )
    assert.is_false(groups.dotnet.visible)
    assert.are_equal(ItemGroup, getmetatable(groups.dotnet._backing_group))
  end)

  it('config.init', function() end)

  it('config.transform_path', function()
    local item = file {
      content = 'foo',
      nameable = false,
      default_name = 'foo',
      label = 'foo',
    }

    local path = item:get_path { cwd = vim.fn.expand('~') }

    assert.matches('__foo$', path)
  end)
end)
