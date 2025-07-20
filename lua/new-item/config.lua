---@class (exact) new-item.Config
---@field icon? boolean enable icons
---@field picker new-item.PickerConfig | fun(items: new-item.AnyItem[]) picker for selecting item

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
function M.setup(conf) M.config = vim.tbl_deep_extend('keep', conf or {}, M.config) end

return M
