local ItemGroup = require('new-item.items').ItemGroup
---@type table<string, Partial<new-item.ItemGroup>?>
local M = setmetatable({}, {
  ---@param group_name string
  ---@param tbl Partial<new-item.ItemGroup>
  __newindex = function(this, group_name, tbl)
    -- NOTE: ItemGroup:new would generate a proxy table
    -- so we should alter tbl first
    tbl.name = group_name
    local new_group = ItemGroup:new(tbl)
    rawset(this, group_name, new_group)
  end,
})

if vim.fn.executable('dotnet') == 1 then
  M.dotnet = {
    visible = function()
      return vim.fs.root(
        vim.fn.expand('%:p:h'),
        function(name, _) return name:match('%.slnx?$') or name:match('%.%w+proj$') end
      ) ~= nil
    end,
    sources = {
      {
        name = 'builtin',
        function(add_items) require('new-item.groups.dotnet').register_items(add_items) end,
      },
    },
  }
end

M.config = {
  visible = true,
  sources = {
    { name = 'builtin', 'new-item.groups.config' },
  },
}

return M
