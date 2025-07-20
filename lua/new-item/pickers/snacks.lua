local util = require('new-item.util')
if not pcall(require, 'snacks.picker') then
  util.error(
    'snacks.nvim is not installed or its picker module is not enabled, please consider either installing/enabling it or use another picker'
  )
  return
end

---@param items new-item.AnyItem[]
return function(items)
  ---@type snacks.picker.Config
  local opts = {
    source = 'New-Item',
    finder = function()
      local ret = {}
      for _, item in ipairs(items) do
        local content
        local ft
        if getmetatable(item) == require('new-item.items').FileItem then
          ---@cast item new-item.FileItem
          content = item:get_content() or item.desc or 'No Preview Available'
          ft = item.filetype
        elseif getmetatable(item) == require('new-item.items').CmdItem then
          ---@cast item new-item.CmdItem
          content = table.concat(item.cmd, ' ')
          ft = 'sh'
        end
        table.insert(
          ret,
          vim.tbl_extend('keep', {
            text = item.label,
            preview = {
              text = content,
              ft = ft,
            },
          }, item)
        )
      end
      return ret
    end,
    preview = 'preview',
    confirm = function(self, item, _)
      self:close()
      ---@diagnostic disable-next-line: invisible
      items[item.idx]._create(vim.deepcopy(items[item.idx]))
    end,
  }

  if not require('new-item.config').config.picker.preview then
    opts.layout = { preset = 'select' }
  end

  Snacks.picker.pick(opts)
end
