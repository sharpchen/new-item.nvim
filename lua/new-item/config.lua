---@class (exact) new-item.Config
---@field icon? boolean enable icons
---@field picker new-item.PickerConfig | fun(items: new-item.AnyItem[]) picker for selecting item
---@field init? fun(groups: table<string, new-item.ItemGroup>, ctors: { file: new-item.FileItem, cmd: new-item.CmdItem })

---@class new-item.PickerConfig
---@field name 'fzf-lua' | 'snacks' | 'telescope' picker name
---@field preview? boolean whether to enable preview
---@field opts? table extra opts for your picker

local M = {}

---@type new-item.Config
---@diagnostic disable-next-line: missing-fields
M.default_config = {
  icon = true,
  picker = {
    name = 'snacks',
    preview = true,
  },
}

M.config = M.default_config

---@param conf? new-item.Config
function M.setup(conf)
  M.config = vim.tbl_deep_extend('keep', conf or {}, M.config)
  if M.config.init then
    M.config.init(require('new-item.groups'), require('new-item.items'))
  end
  M.load_groups()
end

function M.load_groups()
  local util = require('new-item.util')
  for _, group in pairs(require('new-item.groups')) do
    if util.fn_or_val(group.cond) then
      _ = group.load_builtins and group:load_builtins()
    end
  end
end

return M
