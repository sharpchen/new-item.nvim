local M = {}

-- local plug_path = vim.fs.dirname(debug.getinfo(1).source:sub(2))

---@param conf? Partial<new-item.Config>
function M.setup(conf)
  local U = require('new-item.util')
  local groups = require('new-item.groups')
  local newconf =
    vim.tbl_deep_extend('force', require('new-item.config').config, conf or {})

  require('new-item.config').config = newconf

  for name, group_spec in pairs(newconf.groups or {}) do
    -- group_spec can be table or false to disable
    if type(group_spec) == 'table' then
      if groups[name] then
        groups[name]:override(group_spec)
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

  U.load_groups()
end

return M
