local file = require('new-item.items').FileItem
local dir = require('new-item.items').FolderItem
local ItemGroup = require('new-item.items').ItemGroup
---@type table<string, new-item.ItemGroup>
local M = setmetatable({}, {
  ---@param group_name string
  ---@param tbl new-item.ItemGroup
  __newindex = function(this, group_name, tbl)
    local new_group = ItemGroup:new(tbl)
    new_group.name = group_name
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
    fetch_builtins = function(self)
      ---@diagnostic disable-next-line: invisible
      self.builtin_items = {}
      require('new-item.groups.dotnet').register_items_to(self)
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
