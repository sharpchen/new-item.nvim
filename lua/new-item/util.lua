---@diagnostic disable: redefined-local
local uv = vim.loop or vim.uv
local M = {}

---@param args string[]
---@return table<string, string>
function M.prompt_for_args(args)
  local args = {}
  for _, arg in ipairs(args) do
    vim.ui.input(
      { prompt = string.format('%s: ', arg) },
      function(input) args[arg] = input end
    )
  end
  return args
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
    local item = self
    local cwd = item.cwd()
    local name_input
    if item.nameable then
      local default_input
      if item.default_name then default_input = M.fn_or_val(item.default_name) end

      ---@diagnostic disable-next-line: assign-type-mismatch
      name_input = M.prompt_for_name { default = default_input }

      if name_input == nil then
        M.warn('Cancelled')
        return
      elseif name_input == '' then
        M.warn('Name input is empty, creation cancelled')
        return
      end
    end

    ---@type new-item.ItemCreationContext
    local ctx = { name_input = name_input, cwd = cwd }

    ---NOTE: path creation
    opts.path(item, ctx)

    if item.extra_args and #item.extra_args > 0 then
      ctx.args = M.prompt_for_args(item.extra_args)
    end

    ---NOTE: transformation
    opts.transform(item, ctx)

    if M.path_exists(ctx.path) then
      M.error('Item already exist')
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
      'string',
      'not empty when not name_customizable'
    )
  end
end

---@param item new-item.Item
function M.validate_args(item)
  if item.extra_args and #item.extra_args > 0 then
    vim.validate(
      'before_creation',
      item.before_creation,
      'function',
      'should have before_creation when extra_args was specified'
    )
  end
end

return M
