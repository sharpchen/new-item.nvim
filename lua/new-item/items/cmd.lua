local Item = require('new-item.items.item')
local U = require('new-item.util')

---@class (exact) new-item.CmdItem : new-item.Item
---@field exe (string | fun(): string) executable name/path
---@field args (string | fun(): string)[] command args
---@overload fun(o: self): self
---@field edit? boolean Whether to open the item after creation, default to true
---@field env? (table<string, string> | fun(): table<string, string>) environment variables
---@overload fun(o: new-item.CmdItem): new-item.CmdItem
---@diagnostic disable-next-line: assign-type-mismatch
local CmdItem = Item:new {
  edit = true,
  __tostring = function(self)
    ---@cast self new-item.CmdItem
    return 'preview not available for new-item.CmdItem'
  end,
}

---@generic T
---@param self T
---@param o? T | table
---@return T
function CmdItem:new(o)
  o = Item:new(o or {})
  ---@diagnostic disable-next-line: inject-field
  self.__index = self
  local item = setmetatable(o, self)

  if not item.exe and not item.args then
    U.warn('item.exe and item.args are nil for item ' .. item.id)
  end

  return item
end

---@internal
---@param ctx new-item.ItemCreationContext
function CmdItem:get_cmd(ctx)
  ---@param item new-item.CmdItem
  ---@param cmd string[]
  ---@param ctx new-item.ItemCreationContext
  ---@return string[]
  local function expand_special_variables(item, cmd, ctx)
    -- NOTE: %f frontier pattern is supported in luajit
    local function bound_variable(name) return '%$' .. name .. '%f[^%w_]' end

    local new_cmd = {}
    for _, seg in ipairs(cmd) do
      seg = seg
        :gsub(
          bound_variable('ITEM_NAME'),
          ctx.name_input or U.fn_or_val(item.default_name)
        )
        :gsub(bound_variable('ITEM_SUFFIX'), item.suffix or '')
        :gsub(bound_variable('ITEM_PREFIX'), item.prefix or '')
        :gsub(bound_variable('ITEM_PATH'), ctx.path)
        :gsub(bound_variable('ITEM_CWD'), ctx.cwd)

      -- expand extra_args
      for name, arg in pairs(ctx.args or {}) do
        local variable_name = 'ITEM_' .. name:upper()
        seg = seg:gsub(bound_variable(variable_name), arg or '')
      end

      table.insert(new_cmd, seg)
    end

    return new_cmd
  end

  local cmd = { U.fn_or_val(self.exe) }

  for _, arg in ipairs(self.args) do
    table.insert(cmd, U.fn_or_val(arg))
  end

  return expand_special_variables(self, cmd, ctx)
end

function CmdItem:_create()
  (U.item_creator {
    path = function(item, ctx)
      ctx.path = item:get_path {
        cwd = ctx.cwd,
        name_input = ctx.name_input,
      }
    end,
    transform = function(item, ctx)
      ---@cast item new-item.CmdItem
      _ = item.before_create and item:before_create(ctx)
    end,
    creation = function(item, ctx)
      if not U.path_exists(ctx.cwd) then vim.fn.mkdir(ctx.cwd, 'p') end

      U.async_cmd(item:get_cmd(ctx), function(_)
        if item.edit then
          vim.schedule(function()
            ctx.buf = U.edit(ctx.path)

            if item.after_create then item:after_create(ctx) end

            U.warn_if_not_exists(ctx.path)
          end)
        else
          item:after_create(ctx)
          U.warn_if_not_exists(ctx.path)
        end
      end, { cwd = ctx.cwd, env = U.fn_or_val(item.env) or {} })
    end,
  })(self)
end

return CmdItem
