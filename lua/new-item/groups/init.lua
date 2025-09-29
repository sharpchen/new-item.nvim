local file = require('new-item.items').FileItem
local dir = require('new-item.items').FolderItem
local ItemGroup = require('new-item.items').ItemGroup
---@type table<string, new-item.ItemGroup>
local M = setmetatable({}, {
  ---@param group_name string
  ---@param tbl new-item.ItemGroup
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
    cond = function()
      return vim.fs.root(
        vim.fn.expand('%:p:h'),
        function(name, _) return name:match('%.slnx?$') or name:match('%.%w+proj$') end
      ) ~= nil
    end,
    load_builtins = function(self)
      ---@diagnostic disable-next-line: invisible
      self:override { builtin_items = {} }
      require('new-item.groups.dotnet').register_items_to(
        self,
        function() self:invoke_on_loaded() end
      )
    end,
  }
end

M.gitignore = {
  cond = false,
  builtin_items = require('new-item.groups.gitignore'),
}

M.gitattributes = {
  cond = false,
  builtin_items = require('new-item.groups.gitattributes'),
}

M.config = {
  cond = true,
  builtin_items = require('new-item.groups.config'),
}

return M
