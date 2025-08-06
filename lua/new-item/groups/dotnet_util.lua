local util = require('new-item.util')
local M = {
  msbuild = {},
}

--- searching upward to get nearest project file path from cwd
---@param cwd string
---@return string?
function M.get_nearest_proj(cwd)
  local proj
  vim.fs.root(cwd, function(name, path)
    if name:match('%.%w+proj$') then proj = vim.fs.joinpath(path, name) end
  end)
  return proj
end

---@param project string
---@param prop string
---@return string
---@overload fun(project: string, prop: string[]): table<string, string>
function M.msbuild.get_property(project, prop)
  local result
  util
    .async_cmd(
      {
        'dotnet',
        'msbuild',
        project,
        '-getProperty:'
          .. (
            type(prop) == 'string' and prop or table.concat(prop --[[@as string[] ]], ',')
          ),
      },
      function(out)
        result = type(prop) == 'string' and out or vim.json.decode(out).Properties
      end
    )
    :wait()
  return result
end

-- parse templates from `dotnet new list`
---@param kind 'item' | 'project'
---@param callback fun(templates: DotnetTemplate[])
function M.get_templates(kind, callback)
  local dn_gt_7 = false
  util.async_cmd({ 'dotnet', '--version' }, function(version)
    dn_gt_7 = vim.version.ge(version, '7.0.0') --[[@as boolean]]
    util.async_cmd({
      'dotnet',
      'new',
      (dn_gt_7 and 'list' or '--list'),
      '--type=' .. kind,
      -- NOTE: we should probably not ignore constraints
      -- let it conditionally present by project types
      -- '--ignore-constraints',
    }, function(res)
      local templates = vim
        .iter(vim.split(res, '\n'))
        :skip(4)
        :map(function(row)
          ---@cast row string
          ---@type ...string?
          local fullname, alias, lang, tag = unpack(vim.split(vim.trim(row), '%s%s+'))
          if tag == nil then
            tag = lang
            ---@diagnostic disable-next-line: cast-local-type
            lang = nil
          end
          return {
            fullname = fullname,
            alias = alias,
            lang = lang,
            tag = tag,
          }
        end)
        :totable()

      -- split aliases into independent templates
      for _, template in ipairs(templates) do
        ---@cast template DotnetTemplate
        if template.alias:find(',') then
          local aliases = vim.split(template.alias, ',')
          template.alias = aliases[1]
          for i = 2, #aliases do
            table.insert(
              templates,
              vim.tbl_extend('keep', { alias = aliases[i] }, template)
            )
          end
        end
      end

      callback(templates)
    end, { cwd = vim.uv.cwd() })
  end)
end

--- construct namespace base on context
---@param opts { proj: string, root: string, cwd: string }
---@return string namespace folder structure based namespace if opts.structure is specified, else RootNamespace of the project.
function M.get_namespace(opts)
  vim.validate('project file', opts.proj, function(p) return util.path_exists(p) end)
  local root_ns = M.msbuild.get_property(opts.proj, 'RootNamespace')
  local rel = vim.fs.relpath(opts.root, opts.cwd)
  if rel and rel ~= '.' then return root_ns .. '.' .. rel:gsub('/', '.') end
  return root_ns
end

---@param item new-item.CmdItem
---@param ctx new-item.ItemCreationContext
function M.transform_by_ns(item, ctx)
  local proj = M.get_nearest_proj(ctx.cwd)
  item.cmd = vim.list_extend(item.cmd, {
    '--namespace',
    M.get_namespace {
      proj = proj or '',
      ---@diagnostic disable-next-line: assign-type-mismatch
      root = vim.fs.dirname(proj),
      cwd = ctx.cwd,
    },
  })
end

---@param opts { append_ext: boolean }
function M.transform_by_lang(opts)
  return function(item, ctx)
    ---@cast item new-item.CmdItem
    local proj = M.get_nearest_proj(ctx.cwd)

    if proj then
      local ext
      if proj:match('%.csproj$') then
        ext = '.cs'
        item.cmd = vim.list_extend(item.cmd, { '-lang', 'C#' })
      elseif proj:match('%.vbproj$') then
        ext = '.vb'
        item.cmd = vim.list_extend(item.cmd, { '-lang', 'VB' })
      elseif proj:match('%.fsproj$') then
        ext = '.fs'
        item.cmd = vim.list_extend(item.cmd, { '-lang', 'F#' })
      end
      if opts.append_ext then ctx.path = ctx.path .. ext end
    else
      util.warn('project file not found.')
    end
  end
end

return M
