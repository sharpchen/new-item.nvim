---@class new-item.ItemGroup
---@field name? string
---@field cond? boolean | fun(): boolean
---@field items? new-item.AnyItem[]
---@field private builtin_items? new-item.AnyItem[]
---@field enable_builtin? boolean show builtin items
---@field new? fun(self: self, t: table): table
---@field __index? any
---@field __newindex? any
---@field append? fun(self, items: new-item.AnyItem[]) -- append user defined items
---@field get_items? fun(self): new-item.AnyItem[]
---@field fetch_builtins? fun(self: new-item.ItemGroup) how to load/reload builtin items that are typically reliant to external data
local ItemGroup = {
  cond = true,
  enable_builtin = true,
  append = function(self, items)
    ---@cast self new-item.ItemGroup
    ---@cast items new-item.AnyItem[]
    self.items = vim.list_extend(self.items, items)
  end,
  get_items = function(self)
    local items = vim.list_extend(
      { unpack(self.enable_builtin and self.builtin_items or {}) },
      { unpack(self.items) }
    )

    for _, item in ipairs(items) do
      ---@cast item new-item.AnyItem
      if not item.label:match('^%[%w+%]') then
        item.label = string.format('[%s] %s', self.name, item.label)
      end
    end

    return items
  end,
}

---@generic T
---@param self T
---@param o? T | table
---@return T
function ItemGroup:new(o)
  o = o or {}
  o.items = o.items or {}
  self.__index = self
  return setmetatable(o, self)
end

return ItemGroup
