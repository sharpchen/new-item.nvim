---@class new-item.ItemSource
---@field [1] string | fun(add_items: fun(items: new-item.AnyItem[])): new-item.AnyItem[]?
---@field name string
---@field async? boolean

---@class new-item.ItemGroup : table<string, new-item.AnyItem>
---@field name? string
---@field visible? boolean | fun(): boolean
---@field source_loaded boolean indicating whether sources are loaded
---@field private _user_items? new-item.AnyItem[] items added by user instead of sources
---@field items? new-item.AnyItem[] items defined *declaratively* by user during initialization
---@field sources new-item.ItemSource[]
---@field private _source_items table<string, new-item.AnyItem[]>
---@field private _on_loaded_events (fun(self: new-item.ItemGroup))[]
---@field private _backing_group? new-item.ItemGroup
---@field private _excluded_sources string[]
---@field [string] new-item.AnyItem
local ItemGroup = {
  visible = true,
  source_loaded = false,
}

---@param fn fun(self: new-item.ItemGroup)
function ItemGroup:on_loaded(fn) table.insert(self._on_loaded_events, fn) end

--- actually load items to this group
function ItemGroup:load_sources()
  -- -- clear all
  -- self._source_items = {}

  for _, source_spec in ipairs(self.sources or {}) do
    local source = source_spec[1]
    local items
    local this = self

    local function add_items(_items)
      -- FIXME: race condition maybe?
      -- append since user might call it multiple times
      this:append_source_items(source_spec.name, _items)
      this:invoke_on_loaded()
    end

    if type(source) == 'string' then
      items = require(source)
    elseif type(source) == 'function' then
      items = source(add_items)
    end

    self._source_items[source_spec.name] = items or {}
    self.source_loaded = true
  end
end

--- remove source by name
---@param names string | string[]
function ItemGroup:remove_source(names)
  if type(names) == 'string' then
    if not vim.list_contains(self._excluded_sources, names) then
      table.insert(self._excluded_sources, names)
    end
  elseif vim.islist(names) then
    for _, n in ipairs(names) do
      if not vim.list_contains(self._excluded_sources, names) then
        table.insert(self._excluded_sources, n)
      end
    end
  end
end

---@param source new-item.ItemSource
function ItemGroup:append_source(source)
  for idx, name in ipairs(self._excluded_sources) do
    if name == source.name then
      -- remove from blacklist
      table.remove(self._excluded_sources, idx)
      return
    end
  end

  table.insert(self.sources, source)
end

function ItemGroup:invoke_on_loaded()
  for _, fn in ipairs(self._on_loaded_events) do
    fn(self)
  end
end

---append user items
---@param items new-item.AnyItem[]
function ItemGroup:append(items)
  self._user_items = vim.list_extend(self._user_items or {}, items)
end

---@param opts any
function ItemGroup:override(opts)
  -- WARN: ItemGroup is now a proxy table
  for opt, value in pairs(opts) do
    self._backing_group[opt] = value
  end
end

---@return fun(): new-item.AnyItem
function ItemGroup:iter_items()
  if not self.source_loaded then
    -- async sources would not be loaded immediately
    self:load_sources()
  end

  local this = self

  local source_idx = 1
  local source_items = vim.tbl_values(this._source_items)
  local source_names = vim.tbl_keys(this._source_items)
  local inner_idx = 0 -- inner cursor for the nested array in source_items

  local user_item_idx = 0

  local function should_iter_sources()
    local excluded = vim.list_contains(this._excluded_sources, source_names[source_idx])
    if excluded then
      source_idx = source_idx + 1
      return false
    else
      return source_items[source_idx] ~= nil and #source_items[source_idx] > inner_idx
    end
  end

  local function should_iter_user_items() return #this._user_items > user_item_idx end

  return function()
    if should_iter_sources() then
      inner_idx = inner_idx + 1
      if inner_idx == #source_items[source_idx] then
        local temp_source_idx = source_idx
        local temp_inner_idx = inner_idx
        source_idx = source_idx + 1
        inner_idx = 0
        return source_items[temp_source_idx][temp_inner_idx]
      else
        return source_items[source_idx][inner_idx]
      end
    elseif should_iter_user_items() then
      user_item_idx = user_item_idx + 1
      return this._user_items[user_item_idx]
    else
      return nil
    end
  end
end

function ItemGroup:get_items()
  local collect = {}
  local config = require('new-item.config').config

  for item in self:iter_items() do
    item.__picker_label = config.picker
        and config.picker.entry_format
        and config.picker.entry_format(self, item)
      or item.label

    table.insert(collect, item)
  end

  return collect
end

---@param name string
---@param items new-item.AnyItem
function ItemGroup:append_source_items(name, items)
  self._source_items[name] = vim.list_extend(self._source_items[name], items)
end

---@return new-item.ItemGroup
function ItemGroup:new(group)
  group = group or {}

  ---@cast group new-item.ItemGroup

  group.sources = group.sources or {}
  group._source_items = {}
  group._excluded_sources = {}
  group._on_loaded_events = {}

  group._user_items = {}

  if vim.islist(group.items) then
    vim.list_extend(group._user_items, group.items or {})
  end

  self.__index = self
  setmetatable(group, self)

  local wrapper = {
    _backing_group = group,
  } -- NOTE: proxy table
  return setmetatable(wrapper, {
    __index = function(_, key)
      ---@cast group new-item.ItemGroup
      if group[key] then return group[key] end
      for item in group:iter_items() do
        -- group.<id>:override({...})
        if item.id == key then return item end
      end
    end,
  })
end

return ItemGroup
