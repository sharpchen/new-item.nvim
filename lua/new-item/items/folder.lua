local Item = require('new-item.items.item')
---@class (exact) new-item.FolderItem : new-item.Item
---@field children? (new-item.FileItem | new-item.FolderItem)[]
---@overload fun(o: new-item.FileItem): new-item.FileItem
---@diagnostic disable-next-line: assign-type-mismatch
local FolderItem = Item:new {}

return FolderItem
