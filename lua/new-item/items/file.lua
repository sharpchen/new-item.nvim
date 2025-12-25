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
---@overload fun(o: Partial<new-item.FileItem>): new-item.FileItem
---@diagnostic disable-next-line: assign-type-mismatch
local FileItem = Item:new {
  edit = true,
  filetype = 'plain',
  __tostring = function(self)
    ---@cast self new-item.FileItem
    return self:get_content() or self.desc or 'No Preview Available'
  end,
}

---@param o Partial<new-item.FileItem>
---@return new-item.FileItem
function FileItem:new(o)
  o = o or {}
  ---@diagnostic disable-next-line: inject-field
  self.__index = self

  local item = setmetatable(o, self)

  util.validate_name(item)
  util.validate_args(item)

  return item
end

function FileItem:_create()
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
      _ = item.before_create and item:before_create(ctx)
    end,
    creation = function(item, ctx)
      if not util.path_exists(ctx.cwd) then vim.fn.mkdir(ctx.cwd, 'p') end
      if item.edit then
        ctx.buf = util.edit(ctx.path)
        util.fill_buf { buf = 0, content = item.content }

        if item.filetype and vim.bo[ctx.buf].filetype ~= item.filetype then
          vim.bo[ctx.buf].filetype = item.filetype
        end
      else
        local f = io.open(ctx.path, 'w')

        if f then
          f:write(item.content)
          f:close()
          ctx.buf = util.edit(ctx.path)
          if item.filetype and vim.bo[ctx.buf].filetype ~= item.filetype then
            vim.bo[ctx.buf].filetype = item.filetype
          end
        else
          error('Cannot open path: ' .. ctx.path)
        end
      end
      _ = item.after_create and item:after_create(ctx)
    end,
  })(self)
end

---@return string?
function FileItem:get_content()
  if self._content then return self._content end
  if self.link then
    local link = util.fn_or_val(self.link) --[[@as string]]
    if not util.path_exists(link) then util.warn(link .. " doesn't exist.") end
    local fd = io.open(link, 'r')
    self._content = fd and fd:read('*a') or ''
    _ = fd and fd:close()
  else
    self._content = self.content
  end
  return self._content
end

return FileItem
