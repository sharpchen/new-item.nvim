local M = {}

---@class new-item.PickerConfig
---@field name 'select' | 'fzf-lua' | 'snacks' | 'telescope' picker name
---@field preview? boolean whether to enable preview
---@field entry_format? fun(group: new-item.ItemGroup, item: new-item.AnyItem): string
---@field opts? table extra opts for your picker

---@class (exact) new-item.Config
---@field picker new-item.PickerConfig | fun(items: new-item.AnyItem[]) picker for selecting item
---@field init? fun(groups: table<string, new-item.ItemGroup>, ctors: { file: new-item.FileItem, cmd: new-item.CmdItem })
---@field groups? table<string, Partial<new-item.ItemGroup>>
---@field transform_path? fun(path: string): string Global transformer for constructed path
---@field default_cwd? fun(): string? Return nil if current evaluation should be terminated
M.config = {
  picker = {
    name = 'select',
    preview = false,
    entry_format = function(group, item)
      return string.format('[%s] %s', group.name, item.label)
    end,
  },
  transform_path = function(path) return path:gsub('^oil:', '') end,
  default_cwd = function()
    local path = vim.fs.dirname(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
    -- unnamed buffer and scratch buffer have parent '.'
    -- convert it to absolute path otherwise path_exists() cannot read it
    if path == '.' then path = vim.uv.cwd() end
    return path
  end,
  groups = {
    -- disable source named 'builtin'
    -- dotnet = { sources = { builtin = false } },
  },
}

---@return fun(items: new-item.AnyItem[])
function M.get_picker()
  local util = require('new-item.util')
  local picker

  if type(M.config.picker) == 'function' then
    picker = M.config.picker
  elseif M.config.picker.name == 'fzf-lua' then
    picker = require('new-item.pickers.fzf-lua')
  elseif M.config.picker.name == 'snacks' then
    picker = require('new-item.pickers.snacks')
  elseif M.config.picker.name == 'telescope' then
    picker = require('new-item.pickers.telescope')
  elseif M.config.picker.name == 'select' then
    picker = function(items)
      vim.ui.select(items, {
        prompt = 'New-Item',
        format_item = function(item) return item.__picker_label end,
      }, function(item, idx) _ = item and item:invoke() end)
    end
  else
    util.error('picker was not set.')
  end

  if type(picker) == 'boolean' or picker == nil then
    error('picker not valid')
  else
    return picker
  end
end

return M
