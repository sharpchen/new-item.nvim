local util = require('new-item.util')
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
            display = item.label,
            ordinal = item.label,
          }
        end,
      },
      attach_mappings = function(prompt_bufnr, map)
        local actions = require('telescope.actions')
        local action_state = require('telescope.actions.state')
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local item = action_state.get_selected_entry().value
          item._create(vim.deepcopy(item))
        end)
        return true
      end,
      previewer = require('new-item.config').config.picker.preview
          and require('telescope.previewers').new_buffer_previewer {
            define_preview = function(self, entry, status)
              local bufnr = self.state.bufnr
              local content = ''
              local ft = ''
              local item = entry.value
              if getmetatable(item) == require('new-item.items').FileItem then
                ---@cast item new-item.FileItem
                content = item:get_content() or item.desc or 'No Preview Available'
                ft = item.filetype
              elseif getmetatable(item) == require('new-item.items').CmdItem then
                ---@cast item new-item.CmdItem
                content = table.concat(item.cmd, ' ')
                ft = 'sh'
              end

              require('new-item.util').fill_buf { buf = bufnr, content = content }
              vim.treesitter.start(bufnr, vim.treesitter.language.get_lang(ft))
            end,
          }
        or nil,
      sorter = require('telescope.sorters').get_generic_fuzzy_sorter {},
    })
    :find()
end
