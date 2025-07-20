local file = require('new-item.items').FileItem

local root = vim
  .iter(vim.api.nvim_list_runtime_paths())
  :find(function(p) return p:match('new%-item%.nvim$') end)

local gitignores = vim.fs.find(
  function(name, _) return name:match('.+%.gitignore') end,
  { limit = math.huge, type = 'file', path = root }
)

return vim
  .iter(gitignores)
  :map(
    function(path)
      return file {
        label = vim.fs.basename(path),
        nameable = false,
        default_name = '.gitignore',
        link = path,
        filetype = 'gitignore',
      }
    end
  )
  :totable()
