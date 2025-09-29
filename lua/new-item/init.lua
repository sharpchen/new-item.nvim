local M = {}

M.setup = require('new-item.config').setup
local util = require('new-item.util')

vim.api.nvim_create_user_command('NewItem', function(args)
  local picker
  local config = require('new-item.config').config
  if type(config.picker) == 'function' then
    picker = config.picker
  elseif config.picker.name == 'fzf-lua' then
    picker = require('new-item.pickers.fzf-lua')
  elseif config.picker.name == 'snacks' then
    picker = require('new-item.pickers.snacks')
  elseif config.picker.name == 'telescope' then
    picker = require('new-item.pickers.telescope')
  else
    util.error('picker was not set.')
    return
  end

  if type(picker) == 'boolean' then
    util.error('picker not valid.')
    return
  end

  local groups = require('new-item.groups')
  if args.args and args.args ~= '' then
    picker(groups[args.args]:get_items())
  else
    local items = vim
      .iter(vim.tbl_values(groups))
      :filter(function(group)
        ---@cast group new-item.ItemGroup
        return util.fn_or_val(group.cond) --[[@as boolean]]
      end)
      :map(function(group)
        ---@cast group new-item.ItemGroup
        return group:get_items()
      end)
      :flatten()
      :totable()

    table.sort(items, function(a, b) return a.label < b.label end)

    picker(items)
  end
end, {
  nargs = '?',
  complete = function() return vim.tbl_keys(require('new-item.groups')) end,
  desc = 'Create a new item',
})

function M.load_groups()
  for _, group in pairs(require('new-item.groups')) do
    if util.fn_or_val(group.cond) then
      _ = group.load_builtins and group:load_builtins()
    end
  end
end

vim.api.nvim_create_autocmd('DirChanged', {
  group = vim.api.nvim_create_augroup('new-item', { clear = true }),
  callback = function() M.load_groups() end,
})

return M
