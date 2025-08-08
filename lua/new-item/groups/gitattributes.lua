local file = require('new-item.items').FileItem

local root = vim
  .iter(vim.api.nvim_list_runtime_paths())
  :find(function(p) return p:match('new%-item%.nvim$') end)

local gitattributes = vim.fs.find(
  function(name, _) return name:match('.+%.gitattributes') end,
  { limit = math.huge, type = 'file', path = vim.fs.joinpath(root, 'gitattributes') }
)

return vim
  .iter(gitattributes)
  :map(
    function(path)
      return file {
        label = vim.fs.basename(path),
        nameable = false,
        default_name = '.gitattributes',
        link = path,
        filetype = 'gitattributes',
      }
    end
  )
  :totable()
