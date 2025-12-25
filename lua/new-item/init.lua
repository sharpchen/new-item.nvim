local M = {}
local util = require('new-item.util')

-- local plug_path = vim.fs.dirname(debug.getinfo(1).source:sub(2))

---@param conf? Partial<new-item.Config>
function M.setup(conf)
  local groups = require('new-item.groups')
  local newconf =
    vim.tbl_deep_extend('force', require('new-item.config').config, conf or {})

  require('new-item.config').config = newconf

  for name, group_spec in pairs(newconf.groups or {}) do
    if type(group_spec) == 'table' then
      if groups[name] then
        local meta = getmetatable(groups[name])
        local merged = vim.tbl_deep_extend('force', groups[name], group_spec)
        groups[name] = setmetatable(merged, meta)
      else
        groups[name] = group_spec
      end

      --  ability to disable source for existing group
      --  config.groups.dotnet.sources.builtin = false
      for source_name, enabled in pairs(group_spec.sources or {}) do
        if type(source_name) == 'string' then
          -- group already constructed in previous step
          _ = not enabled and groups[name]:remove_source(source_name)
        end
      end
    end
  end

  if newconf.init then newconf.init(groups, require('new-item.items')) end

  util.load_groups()
end

vim.api.nvim_create_user_command('NewItem', function(e)
  local config = require('new-item.config')
  local picker = config.get_picker()
  local groups = require('new-item.groups')

  if e.args then
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
          return util.fn_or_val(group.visible) --[[@as boolean]]
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
  end
end, {
  nargs = '*',
  complete = function(_, cmdline, _)
    local args = vim.split(cmdline, '%s+', { trimempty = true })
    if #args == 1 then -- NewItem <pos>
      return vim.tbl_map(function(g) return g.name end, util.enabled_groups())
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
  callback = function() util.load_groups() end,
})

vim.api.nvim_create_user_command(
  'NewItemReload',
  function(args) util.load_groups() end,
  { desc = 'Reload enabled and visible item groups for current environment' }
)

return M
