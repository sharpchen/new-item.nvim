local M = {}

---@class new-item.PickerConfig
---@field name 'fzf-lua' | 'snacks' | 'telescope' picker name
---@field preview? boolean whether to enable preview
---@field opts? table extra opts for your picker

---@class (exact) new-item.Config
---@field picker new-item.PickerConfig | fun(items: new-item.AnyItem[]) picker for selecting item
---@field init? fun(groups: table<string, new-item.ItemGroup>, ctors: { file: new-item.FileItem, cmd: new-item.CmdItem })
---@field groups? table<string, boolean | Partial<new-item.ItemGroup>>
---@field transform_path? fun(path: string): string global transformer for path constructed
M.config = {
  picker = {
    name = 'snacks',
    preview = false,
  },
  transform_path = function(path) return path:gsub('^oil:', '') end,
  groups = {},
}

return M
