local util = require('new-item.util')
local FileItem = require('new-item.items').FileItem
local CmdItem = require('new-item.items').CmdItem
local config = require('new-item.config').config

if not pcall(require, 'snacks.picker') then
  util.error(
    'snacks.nvim is not installed or its picker module is not enabled, please consider either installing/enabling it or use another picker'
  )
  return
end

---@param items new-item.AnyItem[]
return function(items)
  ---@type snacks.picker.Config
  local opts = {
    source = 'New-Item',
    finder = function()
      local ret = {}
      for _, item in ipairs(items) do
        local content
        local ft

        if getmetatable(item) == FileItem then
          ---@cast item new-item.FileItem
          content = tostring(item)
          ft = item.filetype
        elseif getmetatable(item) == CmdItem then
          ---@cast item new-item.CmdItem
          content = tostring(item)
          ft = 'lua'
        end

        table.insert(ret, {
          wrapped_item = item,
          label = item.__picker_label, -- display
          text = item.label or item.__picker_label, -- fuzzy match
          preview = {
            text = content,
            ft = ft,
          },
        })
      end
      return ret
    end,
    preview = 'preview',
    confirm = function(self, item, _)
      self:close()
      _ = item and item.wrapped_item:invoke()
    end,
  }

  if not config.picker.preview then opts.layout = { preset = 'select' } end

  Snacks.picker.pick(opts)
end
