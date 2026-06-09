local U = require('new-item.util')

vim.api.nvim_create_user_command('NewItem', function(e)
  local C = require('new-item.config')
  local picker = C.get_picker()
  local groups = require('new-item.groups')

  local args = vim.split(e.args, '%s+', { trimempty = true })
  if #args == 1 then -- NewItem dotnet
    local items = groups[e.args] and groups[e.args]:get_items() or {}
    picker(items)
  elseif #args == 2 then -- NewItem dotnet class
    local group_name, item_id = unpack(args)
    local item = groups[group_name][item_id]
    _ = item and item:invoke()
  else
    local items = vim
      .iter(vim.tbl_values(groups))
      :filter(function(group)
        ---@cast group new-item.ItemGroup
        return U.fn_or_val(group.visible) --[[@as boolean]]
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
  nargs = '*',
  complete = function(_, cmdline, _)
    local args = vim.split(cmdline, '%s+', { trimempty = true })
    if #args == 1 then -- NewItem <pos>
      return vim.tbl_map(function(g) return g.name end, U.enabled_groups())
    elseif #args == 2 then -- NewItem <group> <pos>
      local groups = require('new-item.groups')
      local group_name = args[2]
      local items = groups[group_name] and groups[group_name]:get_items() or {}
      return vim.tbl_map(function(i) return i.id end, items)
    else
      return {}
    end
  end,
})

vim.api.nvim_create_autocmd('DirChanged', {
  group = vim.api.nvim_create_augroup('new-item', { clear = true }),
  callback = function() U.load_groups() end,
})

vim.api.nvim_create_user_command(
  'NewItemReload',
  function() U.load_groups() end,
  { desc = 'Reload enabled and visible item groups for current environment' }
)
