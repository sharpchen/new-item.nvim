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
local CmdItem = require('new-item.items').CmdItem
local config = require('new-item.config').config

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
    local content = tostring(item)
    local ft = item.filetype or 'plain'
    local tmpbuf = self:get_tmp_buffer()
    util.fill_buf { buf = tmpbuf, content = content }
    vim.bo[tmpbuf].filetype = ft
    self:set_preview_buf(tmpbuf)
  elseif getmetatable(item) == CmdItem then
    ---@cast item new-item.CmdItem
    local content = tostring(item)
    local tmpbuf = self:get_tmp_buffer()
    util.fill_buf { buf = tmpbuf, content = content }
    vim.bo[tmpbuf].filetype = 'lua'
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
        return string.format('%d: %s  %s', idx, icon, item.__picker_label)
      elseif getmetatable(item) == CmdItem then
        ---@cast item new-item.CmdItem
        return string.format('%d: %s  %s', idx, icon, item.__picker_label)
      end
    end)
    :totable()
end

---@param items new-item.AnyItem[]
return function(items)
  entries = items
  require('fzf-lua').fzf_exec(to_fzf_entries(items), {
    previewer = config.picker.preview and StringPreviewer,
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
          entries[idx]:invoke()
        end
      end,
    },
  })
end
