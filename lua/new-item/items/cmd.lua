local Item = require('new-item.items.item')
local util = require('new-item.util')
---@class (exact) new-item.CmdItem : new-item.Item
---@field cmd string[] shell command
---@overload fun(o: self): self
---@field __call? any
---@field __index? any
---@field new? fun(self, o) : self
---@field edit? boolean Whether to open the item after creation, default to true
---@field append_name? boolean
---@overload fun(o: new-item.CmdItem): new-item.CmdItem
---@diagnostic disable-next-line: assign-type-mismatch
local CmdItem = Item:new {
  edit = true,
  append_name = false,
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

function CmdItem:invoke()
  (util.item_creator {
    path = function(item, ctx)
      ctx.path = item:get_path {
        cwd = ctx.cwd,
        name_input = ctx.name_input,
      }
    end,
    transform = function(item, ctx)
      if item.append_name then
        item.cmd = vim.list_extend(item.cmd, { ctx.name_input })
      end
      _ = item.before_creation and item:before_creation(ctx)
    end,
    creation = function(item, ctx)
      util.async_cmd(item.cmd, function(_)
        if item.edit then vim.schedule(function() vim.cmd.edit(ctx.path) end) end
        _ = item.after_creation and vim.schedule(function() item:after_creation(ctx) end)
      end, { cwd = ctx.cwd })
    end,
  })(self)
end

return CmdItem
