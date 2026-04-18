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

    local proxy = setmetatable({ _backing_group = new_group }, {
      __index = function(this, key)
        local backing = rawget(this, '_backing_group')
        local val = backing[key]

        if val ~= nil then
          if type(val) == 'function' then
            -- wrap it so that instance method call
            -- can pass _backing_group as self parameter
            -- instead of the proxy table
            local delegate = function(self, ...)
              if self == this then
                -- if instance call, pass _backing_group as self
                return val(rawget(this, '_backing_group'), ...)
              else
                return val(...) -- static call such as ItemGroup.visible()
              end
            end

            return delegate
          else
            return val
          end
        end

        for item in backing:iter_items() do
          -- group.<id>:override({...})
          if item.id == key then return item end
        end
      end,
    })

    rawset(this, group_name, proxy)
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
