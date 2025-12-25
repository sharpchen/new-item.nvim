local Item = require('new-item.items.item')
local util = require('new-item.util')

-- NOTE: if someday you like to allow CmdItem.cmd as a function
-- create a ctx field for it, and change the item.cmd references in pickers to nil when cmd a function

---@class (exact) new-item.CmdItem : new-item.Item
---@field cmd string[] shell command
---@overload fun(o: self): self
---@field __call? any
---@field __index? any
---@field new? fun(self, o) : self
---@field edit? boolean Whether to open the item after creation, default to true
---@field env? table<string, string> environment variables
---@overload fun(o: new-item.CmdItem): new-item.CmdItem
---@diagnostic disable-next-line: assign-type-mismatch
local CmdItem = Item:new {
  edit = true,
  __tostring = function(self)
    ---@cast self new-item.CmdItem
    return vim.inspect(self.cmd)
  end,
}

---@generic T
---@param self T
---@param o? T | table
---@return T
function CmdItem:new(o)
  o = o or {}
  ---@diagnostic disable-next-line: inject-field
  self.__index = self
  local item = setmetatable(o, self)

  if next(item.cmd) == nil or item.cmd == nil then
    util.warn('cmd is empty for item ' .. item.label)
  end

  return item
end

---@param ctx new-item.ItemCreationContext
function CmdItem:expand_special_variables(ctx)
  -- NOTE: %f frontier pattern is supported in luajit
  local function bounded_variable(name) return '%$' .. name .. '%f[^%w_]' end

  local cmd = {}
  for _, seg in ipairs(self.cmd) do
    seg = seg
      :gsub(
        bounded_variable('ITEM_NAME'),
        ctx.name_input or util.fn_or_val(self.default_name)
      )
      :gsub(bounded_variable('ITEM_SUFFIX'), self.suffix or '')
      :gsub(bounded_variable('ITEM_PREFIX'), self.prefix or '')
      :gsub(bounded_variable('ITEM_PATH'), ctx.path)
      :gsub(bounded_variable('ITEM_CWD'), ctx.cwd)

    -- expand extra_args
    for name, arg in pairs(ctx.args or {}) do
      local variable_name = 'ITEM_' .. name:upper()
      seg = seg:gsub(bounded_variable(variable_name), arg or '')
    end

    table.insert(cmd, seg)
  end
  return cmd
end

function CmdItem:_create()
  (util.item_creator {
    path = function(item, ctx)
      ctx.path = item:get_path {
        cwd = ctx.cwd,
        name_input = ctx.name_input,
      }
    end,
    transform = function(item, ctx)
      -- expand special variables
      item.cmd = item:expand_special_variables(ctx)
      _ = item.before_create and item:before_create(ctx)
    end,
    creation = function(item, ctx)
      if not util.path_exists(ctx.cwd) then vim.fn.mkdir(ctx.cwd, 'p') end
      util.async_cmd(item.cmd, function(_)
        if item.edit then
          vim.schedule(function()
            ctx.buf = util.edit(ctx.path)
            if item.after_create then item:after_create(ctx) end
            util.warn_if_not_exists(ctx.path)
          end)
        else
          item:after_create(ctx)
          util.warn_if_not_exists(ctx.path)
        end
      end, { cwd = ctx.cwd, env = item.env or {} })
    end,
  })(self)
end

return CmdItem
