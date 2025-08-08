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
  if args.args == 'gitignore' then
    picker(groups.gitignore:get_items())
  elseif args.args == 'gitattributes' then
    picker(groups.gitattributes:get_items())
  else
    local items = vim
      .iter(vim.tbl_values(groups))
      :filter(function(group)
        ---@cast group new-item.ItemGroup
        if type(group.cond) == 'boolean' then
          return group.cond --[[@as boolean]]
        else
          return group.cond and group.cond() or false
        end
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
  complete = function() return { 'gitignore', 'gitattributes' } end,
  desc = 'Create a new item',
})

return M
