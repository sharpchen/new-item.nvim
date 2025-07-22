local Item = require('new-item.items.item')
local util = require('new-item.util')

---@class (exact) new-item.FileItem : new-item.Item
---@field filetype? string
---@field content? string
---@field new? fun(self, o) : self
---@field __index? any
---@field __call? any
---@field edit? boolean Use :edit to create a buffer with pre-fill content instead of direct creation
---@field link? string | fun(): string Use content from another existing file
---@field get_content? fun(self: self): string
---@field create? fun(self: self) Method to apply the item(not factory), provided by user
---@overload fun(o: new-item.FileItem): new-item.FileItem
---@diagnostic disable-next-line: assign-type-mismatch
local FileItem = Item:new {
  edit = true,
  filetype = 'plain',
}

---@generic T
---@param self T
---@param o? T | table
---@return T
function FileItem:new(o)
  o = o or {}
  ---@diagnostic disable-next-line: inject-field
  self.__index = self

  local item = setmetatable(o, self)

  util.validate_name(item)
  util.validate_args(item)

  return item
end

function FileItem:invoke()
  (util.item_creator {
    path = function(item, ctx)
      ctx.path = item:get_path {
        cwd = ctx.cwd,
        name_input = ctx.name_input,
      }
    end,
    transform = function(item, ctx)
      ---@cast item new-item.FileItem
      local content = item:get_content() or ''
      if item.nameable then content = content:gsub('%%s', ctx.name_input) end
      item.content = content
      _ = item.before_creation and item:before_creation(ctx)
    end,
    creation = function(item, ctx)
      if not util.path_exists(ctx.cwd) then vim.fn.mkdir(ctx.cwd, 'p') end
      if item.edit then
        vim.cmd.edit(ctx.path)
        util.fill_buf { buf = 0, content = item.content }
      else
        local f = io.open(ctx.path, 'w')
        if f then
          f:write(item.content)
          f:close()
          vim.cmd.edit(ctx.path)
        else
          error('Cannot open path: ' .. ctx.path)
        end
      end
      _ = item.after_creation and item:after_creation(ctx)
    end,
  })(self)
end

---@return string?
function FileItem:get_content()
  local content
  if self.link then
    local link = util.fn_or_val(self.link) --[[@as string]]
    if not util.path_exists(link) then util.warn(link .. " doesn't exist.") end
    local fd = io.open(link, 'r')
    content = fd and fd:read('*a') or ''
    _ = fd and fd:close()
  else
    content = self.content
  end
  return content
end

return FileItem
