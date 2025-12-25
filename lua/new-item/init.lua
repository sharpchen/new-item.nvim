local M = {}
local util = require('new-item.util')

---@param conf? Partial<new-item.Config>
function M.setup(conf)
  local groups = require('new-item.groups')
  local newconf =
    vim.tbl_deep_extend('force', require('new-item.config').config, conf or {})

  require('new-item.config').config = newconf

  if newconf.init then newconf.init(groups, require('new-item.items')) end

  for name, group in pairs(newconf.groups or {}) do
    if type(group) == 'table' then
      if groups[name] then
        local meta = getmetatable(groups[name])
        local merged = vim.tbl_deep_extend('force', groups[name], group)
        groups[name] = setmetatable(merged, meta)
      end
    end
  end

  util.load_groups()
end

vim.api.nvim_create_user_command('NewItem', function(args)
  local config = require('new-item.config').config
  local picker
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
end, {
  nargs = '?',
  complete = function()
    return vim.iter(util.enabled_groups()):map(function(g) return g.name end):totable()
  end,
  desc = 'Create a new item',
})

vim.api.nvim_create_autocmd('DirChanged', {
  group = vim.api.nvim_create_augroup('new-item', { clear = true }),
  callback = function() util.load_groups() end,
})

return M
