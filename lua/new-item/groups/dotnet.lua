local util = require('new-item.util')
local file = require('new-item.items').FileItem
local config = require('new-item.config').config
local cmd = require('new-item.items').CmdItem
local dn_util = require('new-item.groups.dotnet_util')

local M = {}

function M.register_items(add_items)
  util.async_cmd({ 'dotnet', '--version' }, function(version)
    local dn_ge_7 = vim.version.ge(version, '7.0.0')
    local dn_ge_10 = vim.version.ge(version, '10.0.0')
    local has_slnx_support = vim.version.ge(version, '9.0.200') -- see https://devblogs.microsoft.com/dotnet/introducing-slnx-support-dotnet-cli/
    util.parse_items {
      cmd = { 'dotnet', 'new', dn_ge_7 and 'list' or '--list', '--type=item' }, -- '--ignore-constraints'
      cwd = vim.uv.cwd(),
      parse = function(stdout) return dn_util.parse_template(stdout) end,
      switch = util.make_switch {
        {
          cond = function(parsed) return parsed.alias:match('^avalonia') end,
          action = function(parsed)
            if parsed.alias:match('styles') or parsed.alias:match('resource') then
              return cmd {
                id = parsed.alias,
                label = parsed.alias,
                desc = parsed.fullname,
                cmd = { 'dotnet', 'new', parsed.alias, '-n', '$ITEM_NAME' },
                suffix = '.axaml',
              }
            else
              return cmd {
                id = parsed.alias,
                label = parsed.alias,
                desc = parsed.fullname,
                suffix = '.axaml',
                cmd = { 'dotnet', 'new', parsed.alias, '-n', '$ITEM_NAME' },
                before_create = function(item, ctx)
                  ---@cast item new-item.CmdItem
                  dn_util.transform_by_lang { append_ext = false }(item, ctx)
                  dn_util.transform_by_ns(item, ctx)
                end,
              }
            end
          end,
        },
        {
          cond = function(parsed)
            return parsed.tag:lower() == 'config' and parsed.alias:find('%.') ~= nil
          end,
          action = function(parsed)
            if parsed.alias == 'global.json' then
              return cmd {
                id = parsed.alias,
                label = parsed.alias,
                nameable = false,
                default_name = parsed.alias,
                cmd = {
                  'dotnet',
                  'new',
                  parsed.alias,
                  '--sdk-version',
                  '$ITEM_SDK_VERSION',
                  '--roll-forward',
                  '$ITEM_ROLL_FORWARD_POLICY',
                },
                extra_args = {
                  SDK_VERSION = {
                    desc = '--sdk-version',
                    default = dn_util.sdk_version,
                    complete = dn_util.completion.sdk_versions,
                  },
                  ROLL_FORWARD_POLICY = {
                    desc = '--roll-forward',
                    complete = function()
                      return {
                        'patch',
                        'feature',
                        'minor',
                        'major',
                        'latestPatch',
                        'latestFeature',
                        'latestMinor',
                        'latestMajor',
                        'disable',
                      }
                    end,
                  },
                },
              }
            end
            return cmd {
              id = parsed.alias,
              label = parsed.alias,
              nameable = false,
              default_name = parsed.alias,
              cmd = { 'dotnet', 'new', parsed.alias },
            }
          end,
        },
        {
          cond = function(parsed) return parsed.tag:lower():match('msbuild') end,
          action = function(parsed)
            --  label                                 alias             tag
            -- MSBuild Directory.Build.props file     buildprops        MSBuild/props
            local label = vim.split(parsed.fullname, '%s+', { trimempty = true })[2]
            return cmd {
              id = parsed.alias,
              label = label,
              nameable = false,
              default_name = label,
              cmd = { 'dotnet', 'new', parsed.alias },
            }
          end,
        },
        {
          cond = function(parsed) return parsed.tag:lower() == 'common' end,
          action = function(parsed)
            return cmd {
              id = parsed.alias,
              label = parsed.alias,
              cmd = { 'dotnet', 'new', parsed.alias, '-n', '$ITEM_NAME' },
              before_create = dn_util.transform_by_lang { append_ext = true },
            }
          end,
        },
      },
      callback = function(parsed_items)
        --  items are only parsed
        add_items(parsed_items)

        if has_slnx_support then
          add_items {
            cmd {
              id = 'slnx',
              label = 'slnx',
              cmd = { 'dotnet', 'new', 'sln', '--format', 'slnx', '-n', '$ITEM_NAME' },
              suffix = '.slnx',
              default_name = function() return vim.fs.basename(vim.fn.getcwd()) end,
            },
          }
        end

        add_items {
          -- sln are not included in --type=item
          cmd {
            id = 'sln',
            label = 'sln',
            cmd = vim.list_extend(
              { 'dotnet', 'new', 'sln' },
              has_slnx_support and { '--format', 'sln', '-n', '$ITEM_NAME' } -- defaults to slnx since .NET10, so explicit format is needed
                or { '-n', '$ITEM_NAME' }
            ),
            suffix = '.sln',
            default_name = function() return vim.fs.basename(vim.fn.getcwd()) end,
          },
        }

        --  add some extra items here
        add_items {
          cmd {
            id = 'tool-manifest',
            label = 'dotnet-tools.json',
            cmd = { 'dotnet', 'new', 'tool-manifest' },
            nameable = false,
            default_name = dn_ge_10 and 'dotnet-tools.json'
              or vim.fs.joinpath('.config', 'dotnet-tools.json'),
          },
          cmd {
            id = 'mstest-class',
            label = 'mstest-class',
            cmd = { 'dotnet', 'new', 'mstest-class', '-n', '$ITEM_NAME' },
            before_create = function(item, ctx)
              dn_util.transform_by_lang { append_ext = true }(item, ctx)
            end,
          },
          cmd {
            id = 'viewstart',
            label = 'viewstart',
            nameable = false,
            default_name = '_ViewStart.cshtml',
            cmd = { 'dotnet', 'new', 'viewstart' },
          },
          file {
            id = 'buildrsp',
            label = 'Directory.Build.rsp',
            nameable = false,
            default_name = 'Directory.Build.rsp',
            content = '',
          },
          cmd {
            id = 'viewimports',
            label = 'viewimports',
            nameable = false,
            default_name = '_ViewImports',
            cmd = { 'dotnet', 'new', 'viewimports' },
            suffix = '.cshtml',
            before_create = dn_util.transform_by_ns,
          },
          cmd {
            id = 'razorcomponent',
            label = 'razorcomponent',
            cmd = { 'dotnet', 'new', 'razorcomponent', '-n', '$ITEM_NAME' },
            suffix = '.razor',
          },
          cmd {
            id = 'view',
            label = 'view',
            desc = 'cshtml file',
            cmd = { 'dotnet', 'new', 'view', '-n', '$ITEM_NAME' },
            suffix = '.cshtml',
          },
          cmd {
            id = 'webconfig',
            label = 'web.config',
            cmd = { 'dotnet', 'new', 'webconfig' },
            nameable = false,
            default_name = 'web.config',
          },
          cmd {
            id = 'page',
            label = 'page',
            cmd = { 'dotnet', 'new', 'page', '-n', '$ITEM_NAME' },
            suffix = '.cshtml',
            before_create = dn_util.transform_by_ns,
          },
          cmd {
            id = 'mvccontroller',
            label = 'mvccontroller',
            cmd = { 'dotnet', 'new', 'mvccontroller', '-n', '$ITEM_NAME' },
            before_create = dn_util.transform_by_ns,
          },
          cmd {
            id = 'apicontroller',
            label = 'apicontroller',
            cmd = { 'dotnet', 'new', 'apicontroller', '-n', '$ITEM_NAME' },
            suffix = '.cs',
            before_create = dn_util.transform_by_ns,
          },
        }
      end,
    }
  end)
end

return M
