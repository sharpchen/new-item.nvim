-- TODO: implement item:dryrun()

---@diagnostic disable: invisible
local util = require('new-item.util')

---@class new-item.ItemCreationArgument
---@field default? string | fun(): string
---@field desc? string
--- FIXME: vim.ui.input currently does not support completion literal
---@field complete? string | fun(lead: string, cmdline: string, position: integer): string[] see :h command-completion-custom

---@class new-item.ItemCreationContext
---@field name_input? string name specified from vim.ui.input
---@field args? table<string, string> args input from vim.ui.input
---@field path? string path of the item to be created
---@field cwd? string the folder where the item would be created at
---@field buf? integer the buffer number created for the item

---@class new-item.Item
---@field label string Name displayed as entry in picker
---@field id string Identifier of the item
---@field desc? string Description of the item
---@field cwd? fun(): string? Returns which folder to create the file, default to parent of current buffer
---@field extra_args? table<string, new-item.ItemCreationArgument> Extra argument names to be specified on creation
---@field before_create? fun(self: new-item.AnyItem, ctx: new-item.ItemCreationContext)
---@field after_create? fun(self: new-item.AnyItem, ctx: new-item.ItemCreationContext)
---@field nameable? boolean True if the file item should have a custom name on creation, defaults to true
---@field default_name? string | fun(): string Default name of the item to be created
---@field suffix? string Trailing part of item name. Can be file extension such as `.lua` or suffix like `.test.ts`
---@field prefix? string Leading part of item name
---@overload fun(o: unknown): unknown
local Item = {
  nameable = true,
  cwd = function()
    local default_cwd = require('new-item.config').config.default_cwd
    return default_cwd()
  end,
  before_create = function() end,
  after_create = function() end,
  ---@param o table
  ---@return unknown
  __call = function(this, o)
    ---@cast this { new: fun(self, o: table): table }
    return this:new(o)
  end,
  _on_creation_failed = function(self) end,
}

---@param arg_or_fn new-item.AnyItem
---@return new-item.AnyItem
---@overload fun(self: new-item.AnyItem, fn: fun(final: new-item.AnyItem, prev: new-item.AnyItem))
function Item:override(arg_or_fn)
  if type(arg_or_fn) == 'function' then
    local copy = vim.deepcopy(self)
    setmetatable(copy, getmetatable(self))
    arg_or_fn(self, copy)
    util.validate_args(self)
    util.validate_name(self)
  else
    self = vim.tbl_deep_extend('force', self, arg_or_fn)
  end

  return self
end

---construct a path by contextual inputs
---@param o { name_input?: string, cwd: string }
function Item:get_path(o)
  local config = require('new-item.config').config
  local path = vim.fs.joinpath(
    o.cwd,
    (
      (self.prefix or '')
      .. (o.name_input or util.fn_or_val(self.default_name) or '')
      .. (self.suffix or '')
    )
  )
  if config.transform_path then
    return config.transform_path(path)
  else
    return path
  end
end

---@generic T
---@param self T
---@param o? T | table
---@return T
function Item:new(o)
  self.__index = self
  return setmetatable(o or {}, self)
end

function Item:invoke()
  if self.__test then
    -- NOTE: __test performs nothing
    -- because I don't want to affect file system on tests using invoke()
  else
    local ok, err = pcall(self._create, vim.deepcopy(self))
    if not ok then
      util.warn(string.format('(%s)Item creation failed', self.id))
      self:_on_creation_failed()
      util.error(tostring(err))
    end
  end
end

---@alias new-item.AnyItem (new-item.Item | new-item.FileItem |  new-item.CmdItem)

return Item
