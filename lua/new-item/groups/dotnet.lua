local util = require('new-item.util')
local file = require('new-item.items').FileItem
local config = require('new-item.config').config
local cmd = require('new-item.items').CmdItem
local dn_util = require('new-item.groups.dotnet_util')

local M = {}

---@alias DotnetTemplate { fullname: string, alias: string, lang?: string, tag: string }

---@param group new-item.ItemGroup
function M.register_items_to(group)
  dn_util.get_templates('item', function(templates)
    local items = {}

    vim.list_extend(items, {
      cmd {
        label = 'buildprops',
        nameable = false,
        default_name = 'Directory.Build.props',
        cmd = { 'dotnet', 'new', 'buildprops' },
      },
      cmd {
        label = 'buildtargets',
        nameable = false,
        default_name = 'Directory.Build.targets',
        cmd = { 'dotnet', 'new', 'buildtargets' },
      },
      cmd {
        label = 'packagesprops',
        nameable = false,
        default_name = 'Directory.Packages.props',
        cmd = { 'dotnet', 'new', 'packagesprops' },
      },
      cmd {
        label = 'viewstart',
        nameable = false,
        default_name = '_ViewStart.cshtml',
        cmd = { 'dotnet', 'new', 'viewstart' },
      },
      file {
        label = 'Directory.Build.rsp',
        nameable = false,
        default_name = 'Directory.Build.rsp',
        content = '',
      },
      cmd {
        label = 'viewimports',
        nameable = false,
        default_name = '_ViewImports',
        cmd = { 'dotnet', 'new', 'viewimports' },
        suffix = '.cshtml',
        before_creation = dn_util.transform_by_ns,
      },
      cmd {
        label = 'razorcomponent',
        cmd = { 'dotnet', 'new', 'razorcomponent', '-n' },
        append_name = true,
        suffix = '.razor',
      },
      cmd {
        label = 'view',
        desc = 'cshtml file',
        cmd = { 'dotnet', 'new', 'view', '-n' },
        append_name = true,
        suffix = '.cshtml',
      },
      cmd {
        label = 'webconfig',
        nameable = false,
        default_name = 'web.config',
        cmd = { 'dotnet', 'new', 'webconfig' },
      },
      cmd {
        label = 'page',
        cmd = { 'dotnet', 'new', 'page', '-n' },
        suffix = '.cshtml',
        append_name = true,
        before_creation = dn_util.transform_by_ns,
      },
      cmd {
        label = 'mvccontroller',
        cmd = { 'dotnet', 'new', 'mvccontroller', '-n' },
        append_name = true,
        before_creation = dn_util.transform_by_ns,
      },

      cmd {
        label = 'apicontroller',
        cmd = { 'dotnet', 'new', 'apicontroller', '-n' },
        append_name = true,
        before_creation = dn_util.transform_by_ns,
      },
    })

    for _, shortname in ipairs { 'class', 'interface', 'enum', 'record', 'struct' } do
      table.insert(
        items,
        cmd {
          label = shortname,
          cmd = { 'dotnet', 'new', shortname, '-n' },
          append_name = true,
          before_creation = dn_util.transform_by_lang { append_ext = true },
        }
      )
    end

    for _, shortname in ipairs { 'sln', 'slnx' } do
      table.insert(
        items,
        cmd {
          label = shortname,
          cmd = vim.list_extend(
            { 'dotnet', 'new', 'sln' },
            shortname == 'slnx' and { '--format', 'slnx' } or {}
          ),
          suffix = '.' .. shortname,
          default_name = function() return vim.fs.basename(vim.fn.getcwd()) end,
          before_creation = function(item, ctx)
            item.cmd = vim.list_extend(item.cmd, { '-n', ctx.name_input })
          end,
        }
      )
    end

    -- for the rest of templates in the wild
    for _, template in ipairs(templates) do
      -- skip duplicated templates, they're added manually earlier
      if vim.iter(items):any(function(it) return it.label == template.alias end) then
        goto continue
      end

      -- templates like .gitignore, .editorconfig
      if template.lang == nil and template.alias:match('^%.%w+$') then
        table.insert(
          items,
          cmd {
            label = template.alias,
            desc = template.fullname,
            nameable = false,
            default_name = template.alias,
            cmd = { 'dotnet', 'new', template.alias },
          }
        )
      end
      ::continue::
    end

    ---@diagnostic disable-next-line: invisible
    group.builtin_items = items
  end)
end

return M
