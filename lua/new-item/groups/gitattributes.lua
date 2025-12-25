local file = require('new-item.items').FileItem

---@param plug_name string basename of the github/gitignore repo being installed on stdpath
---@return new-item.FileItem[]
return function(plug_name)
  plug_name = plug_name or 'gitattributes'

  local root = vim.iter(vim.api.nvim_list_runtime_paths()):find(
    function(p) return vim.fs.basename(p):match(string.format('^%s$', plug_name)) end
  )

  local gitattributes = root
      and vim.fs.find(
        function(name, _) return name:match('.+%.gitattributes$') end,
        { limit = math.huge, type = 'file', path = root }
      )
    or {}

  return vim
    .iter(gitattributes)
    :map(
      function(path)
        return file {
          id = vim.fn.fnamemodify(path, ':t:r'),
          label = vim.fs.relpath(root, path),
          nameable = false,
          default_name = '.gitattributes',
          link = path,
          filetype = 'gitattributes',
        }
      end
    )
    :totable()
end
