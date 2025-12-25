local util = require('new-item.util')
local FileItem = require('new-item.items').FileItem
local CmdItem = require('new-item.items').CmdItem

if not pcall(require, 'telescope') then
  util.error(
    'telescope.nvim is not installed, please consider either installing it or use another picker'
  )
  return
end

---@param items new-item.AnyItem[]
return function(items)
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local config = require('new-item.config').config
  pickers
    .new(config.picker.opts and config.picker.opts or {}, {
      prompt_title = 'New-Item',
      finder = finders.new_table {
        results = items,
        entry_maker = function(item)
          return {
            value = item,
            display = item.__picker_label,
            ordinal = item.label or item.__picker_label,
          }
        end,
      },
      attach_mappings = function(prompt_bufnr, map)
        local actions = require('telescope.actions')
        local action_state = require('telescope.actions.state')
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local item = action_state.get_selected_entry().value
          _ = item and item:invoke()
        end)
        return true
      end,
      previewer = config.picker.preview
        and require('telescope.previewers').new_buffer_previewer {
          define_preview = function(self, entry, status)
            local bufnr = self.state.bufnr
            local content = ''
            local ft = ''
            local item = entry.value
            if getmetatable(item) == FileItem then
              ---@cast item new-item.FileItem
              content = tostring(item)
              ft = item.filetype
            elseif getmetatable(item) == CmdItem then
              ---@cast item new-item.CmdItem
              content = tostring(item)
              ft = 'lua'
            end

            util.fill_buf { buf = bufnr, content = content }
            pcall(vim.treesitter.start, bufnr, vim.treesitter.language.get_lang(ft))
          end,
        },
      sorter = require('telescope.sorters').get_generic_fuzzy_sorter {},
    })
    :find()
end
