local util = require('new-item.util')
if not pcall(require, 'fzf-lua') then
  util.warn(
    'fzf-lua is not installed, please consider either installing it or use another picker'
  )
  return
end

local entries

local StringPreviewer = require('fzf-lua.previewer.builtin').base:extend()
local FileItem = require('new-item.items').FileItem
local FolderItem = require('new-item.items').FolderItem
local CmdItem = require('new-item.items').CmdItem

function StringPreviewer:new(o, opts, fzf_win)
  StringPreviewer.super.new(self, o, opts, fzf_win)
  setmetatable(self, StringPreviewer)
  return self
end

function StringPreviewer:populate_preview_buf(entry_str)
  ---@cast entry_str string
  local idx = tonumber(entry_str:match('(%d+):'))
  assert(idx)
  local item = entries[idx]
  assert(item)
  if getmetatable(item) == FileItem then
    ---@cast item new-item.FileItem
    local content = item:get_content() or item.desc or 'No Preview Available'
    local ft = item.filetype or 'plain'
    local tmpbuf = self:get_tmp_buffer()
    util.fill_buf { buf = tmpbuf, content = content }
    vim.bo[tmpbuf].filetype = ft
    self:set_preview_buf(tmpbuf)
  elseif getmetatable(item) == FolderItem then
    ---TODO: handle FolderItem
  elseif getmetatable(item) == CmdItem then
    ---@cast item new-item.CmdItem
    local content = table.concat(item.cmd, ' ')
    local tmpbuf = self:get_tmp_buffer()
    util.fill_buf { buf = tmpbuf, content = content }
    vim.bo[tmpbuf].filetype = 'sh'
    self:set_preview_buf(tmpbuf)
  end
end

function StringPreviewer:gen_winopts()
  local new_winopts = {
    wrap = false,
    number = true,
    cursorline = false,
  }
  return vim.tbl_extend('force', self.winopts, new_winopts)
end

---@param items new-item.AnyItem[]
---@return string[]
local function to_fzf_entries(items)
  return vim
    .iter(ipairs(items))
    :map(function(idx, item)
      if getmetatable(item) == FileItem then
        ---@cast item new-item.FileItem
        local icon = util.icon_by_ft(item.filetype, item.suffix)
        vim.validate('icon', icon, 'string')
        return string.format('%d: %s  %s', idx, icon, item.label)
      elseif getmetatable(item) == CmdItem then
        ---@cast item new-item.CmdItem
        local icon = util.icon_by_ft('sh', item.suffix)
        vim.validate('icon', icon, 'string')
        return string.format('%d: %s  %s', idx, icon, item.label)
      elseif getmetatable(item) == FolderItem then
        --TODO:
      end
    end)
    :totable()
end

---@param items new-item.AnyItem[]
return function(items)
  entries = items
  require('fzf-lua').fzf_exec(to_fzf_entries(items), {
    previewer = require('new-item.config').config.picker.preview and StringPreviewer
      or nil,
    winopts = {
      title = ' New-Item ',
    },
    actions = {
      default = function(selected, _)
        ---@cast selected string[]
        for _, entry in ipairs(selected) do
          local idx = tonumber(entry:match('(%d+):'))
          assert(idx)
          ---@diagnostic disable-next-line: invisible
          entries[idx]._create(vim.deepcopy(entries[idx]))
        end
      end,
    },
  })
end
