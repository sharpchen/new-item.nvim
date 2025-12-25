---@diagnostic disable: redefined-local
local uv = vim.loop or vim.uv
local M = {}

---@param args table<string, new-item.ItemCreationArgument>
---@return table<string, string>
function M.prompt_for_args(args, ctx)
  local ret = {}
  for name, spec in pairs(args) do
    vim.ui.input({
      prompt = name .. (spec.desc and string.format('(%s)', spec.desc) or '') .. ': ',
      default = M.fn_or_val(spec.default, ctx),
      -- completion = spec.complete,
    }, function(input)
      if not input then error(string.format('extra_args.%s cancelled', name), 0) end
      ret[name] = input
    end)
  end
  return ret
end

---@param opts? { default?: string }
---@return string?
function M.prompt_for_name(opts)
  local name
  vim.ui.input(
    { prompt = 'Item Name: ', default = opts and opts.default or '' },
    function(input) name = input end
  )
  return name
end

---@param ft string
---@param suffix? string
---@return string
function M.icon_by_ft(ft, suffix)
  local ok, devicon = pcall(require, 'nvim-web-devicons')

  if not ok then return '' end

  local icon, icon_color = devicon.get_icon_color_by_filetype(ft)
  if not icon and suffix then
    icon, icon_color = devicon.get_icon_color_by_filetype(suffix)
  end

  return icon or devicon.get_default_icon().icon
end

---simple async cmd to fetch single result.
---@param cmd string[]
---@param cb? fun(result: string) callback for using returned result
---@param opts? vim.SystemOpts
---@return vim.SystemObj
function M.async_cmd(cmd, cb, opts)
  cb = cb or function(_) end
  opts = vim.tbl_extend('keep', opts or {}, { text = true })
  return vim.system(cmd, opts, function(out)
    if out.code ~= 0 then
      vim.schedule(function()
        M.error(
          ('async job for %s exited with code %d.'):format(vim.inspect(cmd), out.code)
        )
        M.error((('error: %s'):format(out.stderr)))
      end)
      return
    end
    local result = vim.trim(out.stdout)
    cb(result)
  end)
end

---@param msg string
function M.warn(msg) vim.notify(msg, vim.log.levels.WARN, { title = ' New-Item' }) end

---@param msg string
function M.error(msg) vim.notify(msg, vim.log.levels.ERROR, { title = ' New-Item' }) end

--- WARN: use vim.text.indent instead
--- dedent lua raw string
---@param s string
function M.dedent(s)
  local lines = vim.split(s, '\n')
  local indent = lines[1]:match('^(%s*)'):len()
  return vim.iter(lines):fold('', function(sum, current)
    ---@cast current string
    ---@cast sum string
    return sum
      .. (sum == '' and '' or '\n')
      .. current:gsub('^' .. string.rep('%s', indent), '')
  end)
end

---@generic T
---@param fov (T | fun(...): T)
---@param ... T? params for function
---@return T
function M.fn_or_val(fov, ...)
  if type(fov) == 'function' then
    return fov(...)
  else
    return fov
  end
end

---@param opts { buf: integer, content: string }
function M.fill_buf(opts)
  vim.api.nvim_buf_set_lines(
    opts.buf,
    0,
    -1,
    false,
    opts.content:match('\n') and vim.split(opts.content, '\n') or { opts.content }
  )
end

---@param path string
---@return boolean
function M.path_exists(path) return uv.fs_stat(path) ~= nil end

---@alias new-item.CtxCallback fun(item: new-item.AnyItem, ctx: new-item.ItemCreationContext)

---@param opts { path: new-item.CtxCallback, transform: new-item.CtxCallback, creation: new-item.CtxCallback }
---@return fun(self: new-item.AnyItem)
function M.item_creator(opts)
  return function(self)
    local config = require('new-item.config').config
    local item = self
    local cwd = item.cwd()

    if not cwd then
      M.error(
        "`item.cwd == nil` indicates that it's not appropriate to execute with current context"
      )
      return
    end

    -- should transform cwd first because mkdir uses it
    -- WARN: BUT this would call it one more time
    -- which could produce unexpected result
    -- so transform_path might not sufficient
    -- we might need a transform_cwd
    cwd = config.transform_path and config.transform_path(cwd) or cwd

    local name_input
    if item.nameable then
      if item.label:match('git') then print('fooo') end
      local default_input = item.default_name and M.fn_or_val(item.default_name)

      ---@diagnostic disable-next-line: assign-type-mismatch
      name_input = M.prompt_for_name { default = default_input }

      if name_input == nil or name_input == '' then
        M.warn(
          string.format(
            'ctx.name_input is %s, creation cancelled',
            name_input == '' and 'empty' or 'nil'
          )
        )
        return
      end
    end

    ---@type new-item.ItemCreationContext
    local ctx = { name_input = name_input, cwd = cwd }

    ---NOTE: path creation
    opts.path(item, ctx)

    if item.extra_args then
      local ok, args = pcall(M.prompt_for_args, item.extra_args, ctx)
      if not ok then
        M.warn(args)
        return
      end
      ctx.args = args
    end

    ---NOTE: transformation
    opts.transform(item, ctx)

    if M.path_exists(ctx.path) then
      M.error('Item already exists, operation cancelled.')
      return
    end

    --NOTE: creation
    opts.creation(item, ctx)
  end
end

---@param item new-item.Item
function M.validate_name(item)
  if not item.nameable then
    vim.validate(
      'default_name',
      item.default_name,
      { 'string', 'function' },
      'not empty when not nameable'
    )
  end
end

---@param item new-item.Item
function M.validate_args(item)
  if item.extra_args and #item.extra_args > 0 then
    vim.validate(
      'before_create',
      item.before_create,
      'function',
      'should have before_create when extra_args was specified'
    )
  end
end

---@return new-item.ItemGroup[]
function M.enabled_groups()
  local groups = require('new-item.groups')
  local ret = {}
  for _, group in pairs(groups) do
    if require('new-item.config').config.groups[group.name] ~= false then
      table.insert(ret, group)
    end
  end
  return ret
end

---@return new-item.ItemGroup[]
function M.loaded_groups()
  local groups = require('new-item.groups')
  local ret = {}
  for _, group in pairs(groups) do
    if group.source_loaded then table.insert(ret, group) end
  end
  return ret
end

function M.visible_groups()
  local groups = require('new-item.groups')
  local ret = {}
  for _, group in pairs(groups) do
    if group.source_loaded and M.fn_or_val(group.visible) then
      table.insert(ret, group)
    end
  end
  return ret
end

function M.load_groups()
  local groups = require('new-item.groups')
  local config = require('new-item.config').config

  for _, group in pairs(groups) do
    local enabled = config.groups[group.name] ~= false -- nil defaults to true
    if enabled and M.fn_or_val(group.visible) then group:load_sources() end
  end
end

---@generic TInput
---@generic TResult
---@param spec { cond: (fun(input: TInput): boolean), action: (fun(input: TInput): TResult) }[]
---@return fun(input: TInput | TInput[]): TResult[]
function M.make_switch(spec)
  return function(source)
    local inputs = vim.islist(source) and source or { source }
    local outputs = {}
    for _, input in ipairs(inputs) do
      for _, pair in ipairs(spec) do
        if pair.cond(input) then
          local out = pair.action(input)
          _ = out and table.insert(outputs, out)
          break -- only match once
        end
      end
    end
    return #outputs > 0 and outputs
  end
end

---@param opts { cmd: string[], cwd: string, parse: (fun(stdout: string): any[]), switch: (fun(sources: any[]): any[]), callback: fun(items) }
function M.parse_items(opts)
  M.async_cmd(opts.cmd, function(out)
    local sources = opts.parse(out)
    local items = opts.switch(sources)
    opts.callback(items)
  end, { cwd = opts.cwd })
end

---@param path string
---@return integer buffer number for the opened path
function M.edit(path)
  local buf = vim.fn.bufadd(path)
  vim.bo[buf].buflisted = true
  if M.path_exists(path) then vim.fn.bufload(buf) end
  vim.api.nvim_set_current_buf(buf)
  return buf
end

function M.warn_if_not_exists(path)
  if not M.path_exists(path) then
    M.warn(
      string.format(
        'Item path "%s" does not exist after creation, there might be a problem with the item definition',
        path
      )
    )
  end
end

return M
