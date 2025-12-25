local file = require('new-item.items').FileItem

---@param plug_name string basename of the github/gitignore repo being installed on stdpath
---@return new-item.FileItem[]
return function(plug_name)
  plug_name = plug_name or 'gitignore'
  local root = vim.iter(vim.api.nvim_list_runtime_paths()):find(
    function(p) return vim.fs.basename(p):match(string.format('^%s$', plug_name)) end
  )
  local gitignores = root
      and vim.fs.find(
        function(name, _) return name:match('.+%.gitignore$') end,
        { limit = math.huge, type = 'file', path = root }
      )
    or {}

  return vim
    .iter(gitignores)
    :map(
      function(path)
        return file {
          id = vim.fn.fnamemodify(path, ':t:r'),
          label = vim.fs.relpath(root, path),
          nameable = false,
          default_name = '.gitignore',
          link = path,
          filetype = 'gitignore',
        }
      end
    )
    :totable()
end
