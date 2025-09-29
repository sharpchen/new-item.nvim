---@diagnostic disable: invisible
local util = require('new-item.util')

---@class new-item.ItemCreationContext
---@field name_input? string name specified from vim.ui.input
---@field args? table<string, string> args input from vim.ui.input
---@field path? string path of the item to be created
---@field cwd? string the folder where the item would be created at

---@class new-item.Item
---@field label string Name displayed as entry in picker
---@field iname string Identifier of the item
---@field desc? string Description of the item
---@field invoke? fun(self: self) Activate the creation for this item
---@field private _create? fun(self: self) Method to apply the item(not factory)
---@field cwd? fun(): string Returns which folder to create the file, default to parent of current buffer
---@field extra_args? string[] Extra argument names to be specified on creation
---@field before_creation? fun(self: new-item.AnyItem, ctx: new-item.ItemCreationContext)
---@field after_creation? fun(self: new-item.AnyItem, ctx: new-item.ItemCreationContext)
---@field new? fun(self, o) : self
---@field nameable? boolean True if the file item should have a custom name on creation, defaults to true
---@field default_name? string | fun(): string Default name of the item to be created
---@field suffix? string Trailing part of item name. Can be file extension such as `.lua` or suffix like `.test.ts`
---@field prefix? string Leading part of item name
---@field private _on_creation_failed? fun(self: self) Actions should perform on creation failed
---@overload fun(o: unknown): unknown
local Item = {
  nameable = true,
  cwd = function()
    local parent =
      vim.fs.dirname(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
    local cwd, _ = parent:gsub('^oil:', '') -- truncate oil prefix
    return cwd
  end,
  ---@param o table
  ---@return unknown
  __call = function(this, o)
    ---@cast this { new: fun(self, o: table): table }
    return this:new(o)
  end,
  _create = function(self)
    local ok, err = pcall(self.invoke, self)
    if not ok then
      util.warn('Item creation failed')
      self:_on_creation_failed()
      util.error(tostring(err))
    end
  end,
  _on_creation_failed = function(self) end,
}

---@param arg new-item.AnyItem
---@overload fun(self: new-item.AnyItem, fn: fun(self: new-item.AnyItem, prev: new-item.AnyItem))
function Item:override(arg)
  if type(arg) == 'function' then
    arg(self, vim.deepcopy(self))
  else
    self = vim.tbl_deep_extend('force', self, arg)
  end
end

---@param o { name_input: string?, cwd: string, default_name: string }
function Item:get_path(o)
  return vim.fs.joinpath(
    o.cwd,
    (
      (self.prefix or '')
      .. (o.name_input or util.fn_or_val(self.default_name) or '')
      .. (self.suffix or '')
    )
  )
end

---@generic T
---@param self T
---@param o? T | table
---@return T
function Item:new(o)
  self.__index = self
  return setmetatable(o or {}, self)
end

---@alias new-item.AnyItem (new-item.Item | new-item.FileItem | new-item.FolderItem | new-item.CmdItem)

return Item
