---@class new-item.ItemGroup : table<string, new-item.AnyItem>
---@field name? string
---@field cond? boolean | fun(): boolean
---@field items? new-item.AnyItem[]
---@field private builtin_items? new-item.AnyItem[]
---@field enable_builtin? boolean show builtin items
---@field append? fun(self, items: new-item.AnyItem[]) -- append user defined items
---@field load_builtins? fun(self: new-item.ItemGroup) how to load/reload builtin items that are typically reliant to external data
---@field private _on_loaded_events? (fun(self: new-item.ItemGroup))[]
---@field private _backing_group? new-item.ItemGroup
---@field [string] new-item.AnyItem
local ItemGroup = {
  cond = true,
  enable_builtin = true,
}

---@param fn fun(self: new-item.ItemGroup)
function ItemGroup:on_loaded(fn) table.insert(self._on_loaded_events, fn) end

function ItemGroup:invoke_on_loaded()
  for _, fn in ipairs(self._on_loaded_events) do
    fn(self)
  end
end

---@param items new-item.AnyItem[]
function ItemGroup:append(items) self.items = vim.list_extend(self.items, items) end

---@param opts { cond: (boolean | fun(): boolean), builtin_items: new-item.AnyItem[] }
function ItemGroup:override(opts)
  -- WARN: ItemGroup is now a proxy table
  for opt, value in pairs(opts) do
    self._backing_group[opt] = value
  end
end

function ItemGroup:get_items()
  local items = vim.list_extend(
    { unpack(self.enable_builtin and self.builtin_items or {}) },
    { unpack(self.items) }
  )

  for _, item in ipairs(items) do
    ---@cast item new-item.AnyItem
    -- NOTE: dirty appendage,  maybe should use a dynamic evaluation or something
    if self.name and not item.label:match('^%[%w+%]') then
      item.label = string.format('[%s] %s', self.name, item.label)
    end
  end

  return items
end

---@generic T
---@param self T
---@param group? T | table
---@return T
function ItemGroup:new(group)
  group = group or {}
  group.items = group.items or {}
  group._on_loaded_events = {}
  self.__index = self
  setmetatable(group, self)

  local wrapper = {
    _backing_group = group,
  } -- NOTE: proxy table
  return setmetatable(wrapper, {
    __index = function(_, key)
      ---@cast group new-item.ItemGroup
      if group[key] then return group[key] end
      for _, item in pairs(group:get_items()) do
        -- group.<iname>:override({...})
        if item.iname == key then return item end
      end
    end,
  })
end

return ItemGroup
