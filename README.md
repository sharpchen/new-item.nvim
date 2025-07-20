# new-item.nvim

Creating items from context-aware templates.

![new-item](https://github.com/user-attachments/assets/ed260dea-a3b9-4063-a540-66b9cf7b0f68)

## Why this plugin

The idea came from the common feature of modern IDEs that, allowing to create a file based on template and context, things like **Add new class** in the menu while you right-click in the explorer.
This plugin was designed to be a **scaffold** to write your own template with context-aware capabilities.

## Installation

- [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'sharpchen/new-item.nvim',
  event = 'VeryLazy',
  submodules = true,
  config = function()
    require('new-item').setup {
      picker = {
        name = 'snacks', -- or 'fzf-lua' or 'telescope'
        preview = false,
      }
    }
    vim.keymap.set('n', '<leader>ni', '<cmd>NewItem<CR>')
  end
}
```

## Item & Item Group

An **Item** is a template knows how to create a thing, an `ItemGroup` is a dynamically conditioned container for items.
This plugin was written in a object-oriented style, each type of item was derived from `new-item.Item`, any kind of item has the following fields:

- `suffix` and `prefix`: parts around the name of item.
    - for example, to create a typescript test file, the `suffix` can be `.test.ts`, and the final name would be `<name>.test.ts`.
- `nameable`: indicating whether the item can have a custom name.
    - for example, a `.gitignore` is always `.gitignore`, it should be not `nameable`.
    - if an item is not `nameable`, it must have a `default_name`.
- `default_name`: a default value for the name, can evaluate dynamically.
    - `default_name` is the pre-filled input of `vim.ui.input` during creation when the item is `nameable`.
- `cwd`: the folder where the item would be created at, **defaults to parent of current buffer.**
- `edit`: presume the item created is a file, and open it after creation.
- `extra_args`; an array of argument names, each argument will have an input request during creation.
    - you can use these arguments in `before_creation` to do transformation.
- `before_creation(item, ctx)`: to perform a transformation before actually creating the item
    - you may transform things like the content or path, even the item template itself(it's an copy of original one)
- `after_creation(item, ctx)`: to perform after creation

<details>
<summary>Item base definition</summary>

```lua
---@class new-item.Item
---@field label string Name displayed as entry in picker
---@field desc? string Description of the item
---@field invoke? fun(self: self) Activate the creation for this item
---@field cwd? fun(): string Returns which parent folder to create the file, default to parent of current buffer
---@field extra_args? string[] Extra argument names to be specified on creation
---@field before_creation? fun(self: new-item.AnyItem, ctx: new-item.ItemCreationContext)
---@field after_creation? fun(self: new-item.AnyItem, ctx: new-item.ItemCreationContext)
---@field nameable? boolean True if the file item should have a custom name on creation
---@field default_name? string | fun(): string Default name of the item to be created
---@field suffix? string Trailing content of the constructed item name. Can be file extension such as `.lua` or suffix like `.test.ts`
---@field prefix? string Leading content of the constructed item name
```

</details>

### Writing items

1. `FileItem`: creating item from string content.

<details>
<summary>FileItem definition</summary>

```lua
---@class (exact) new-item.FileItem : new-item.Item
---@field filetype? string
---@field content? string
---@field edit? boolean Use :edit to create a buffer with pre-fill content instead of direct creation
---@field link? string | fun(): string Use content from another existing file
---@overload fun(o: new-item.FileItem): new-item.FileItem
```

</details>

```lua
local file = require('new-item.items').FileItem
require('new-item.groups').javascript:append { -- assuming javascript is a existing item group
  file {
    label = 'new javascript file',
    content = 'console.log("%s")', -- %s would be replaced by name input
    filetype = 'javascript', -- for treesitter highlighting
    suffix = '.js' -- extension of the file
  }
  file {
    label = '.prettierrc',
    edit = false, -- do not open the file after creation
    link = vim.fn.expand('~/.prettierrc'), -- use content of an existing file
    nameable = false, -- .prettierrc is always .prettierrc
    default_name = '.prettierrc',
    filetype = 'json',
    cwd = function() return vim.fn.getcwd() end, -- should always add to project root
  },
}
require('new-item.groups').md:append {
  -- use the file name as top level title
  file {
    label = 'Markdown file',
    filetype = 'markdown',
    suffix = '.md',
    content = [[# %s]],
  },
}
```

2. `CmdItem`: creating item by executing a shell command, and we can presume the item created is a file.

<details>
<summary>CmdItem definition</summary>

```lua
---@class (exact) new-item.CmdItem : new-item.Item
---@field cmd string[]
---@field edit? boolean Whether to open the item after creation, default to true
---@field append_name? boolean whether to append ctx.name_input to item.cmd
---@overload fun(o: new-item.CmdItem): new-item.CmdItem
```

</details>

The following examples shows how it wrap `dotnet new` command as a template.

```lua
local cmd = require('new-item.items').CmdItem
require('new-item.groups').dotnet:append {
  cmd {
    label = 'buildtargets',
    nameable = false,
    default_name = 'Directory.Build.targets',
    cmd = { 'dotnet', 'new', 'buildtargets' },
  },
  cmd {
    label = 'class',
    cmd = { 'dotnet', 'new', 'class', '-lang', 'C#', '--name' } -- argument of --name is not given
    before_creation = function(item, ctx)
      item.cmd = vim.list_extend(item.cmd, { ctx.name_input }) -- append name argument
    end
  },
  -- or use append_name so you don't have to manually append it
  cmd {
    label = 'slnx',
    cmd = { 'dotnet', 'new', 'sln', '--format', 'slnx', '--name' },
    suffix = '.slnx',
    append_name = true, -- implicitly append name_input to item.cmd
    default_name = function() return vim.fs.basename(vim.fn.getcwd()) end, -- use root folder name as default
  }
}
```

#### Using transformation

You can transform  `item` and `ctx` on `before_creation` to let it be a context-aware template.
A context contains temporary values generated during the creation, such as `name_input`, `cwd` etc.

<details>
<summary>ItemCreationContext definition</summary>

```lua
---@class new-item.ItemCreationContext
---@field name_input? string name specified from vim.ui.input
---@field args? table<string, string> args input from vim.ui.input
---@field path? string path of the item to be created
---@field cwd? string the folder where the item would be created at
```

</details>

The following example shows how to use a `FileItem` create a new `C#` class using its current folder structure as namespace.

```lua
local util = require('new-item.util')
require('new-item.groups').dotnet:append {
  file {
    label = 'class',
    suffix = '.cs',
    filetype = 'cs',
    content = util.dedent([[
    namespace <namespace>;
    public class %s { }
    ]]),
    before_creation = function(item, ctx)
      local proj
      vim.fs.root(ctx.cwd, function(name, path)
        if name:match('%.%w+proj$') then proj = vim.fs.joinpath(path, name) end
      end)
      local root_ns, ns
      vim.system({ 'dotnet', 'msbuild', proj, '-getProperty:RootNamespace' }, { text = true },
          function(out)
            if out.code == 0 then root_ns = vim.trim(out.stdout) end
          end):wait()
      local rel = vim.fs.relpath(vim.fs.dirname(proj), ctx.cwd)
      if rel and rel ~= '.' then
        ns = root_ns .. '.' .. rel:gsub('/', '.')
      else
        ns = root_ns
      end
      item.content = item.content:gsub('<namespace>', ns)
    end,
  },
}
```

### Writing item group

Each item must be of certain group, each group has a `cond` field to be evaluated dynamically to indicate whether its contained items should present each time your invoke the picker.

- `cond(): boolean`: indicating whether its items should present in picker.
- `items`: user-defined templates.
- `builtin_items`: pre-defined templates from the plugin or other sources.
- `enable_builtin`: whether to include `builtin_items` in picker.
- `append(self, items)`: append extra templates to `itemgroup.items` list.

<details>
<summary>ItemGroup definition</summary>

```lua
---@class new-item.ItemGroup
---@field name? string
---@field cond? boolean | fun(): boolean
---@field items? new-item.AnyItem[]
---@field enable_builtin? boolean show builtin items
---@field private builtin_items? new-item.AnyItem[]
---@field append? fun(self, items: new-item.AnyItem[]) -- append user defined items
---@field get_items? fun(self): new-item.AnyItem[]
```

</details>

For example, you may require javascript templates to present only when it found a `package.json` file on root.

```lua
require('new-item.groups').javascript = {
  cond = function()
    return vim.fs.root(vim.fn.expand('%:p:h'), 'package.json') ~= nil
  end,
  items = {--[[...]]}
}
```

You can add any number of groups for your specific working environments.

### How does it work

1. an item name was decided by either `ctx.name_input` or `default_name`, depending on whether the template is `nameable`.
2. path of the item to be created was composed by the item name, `cwd`, `suffix` and `prefix`.
3. `before_creation` was then triggered, might perform some transformation.
4. `item:invoke()` was triggered to create the item.
5. `after_creation` was triggered to perform a post action.

## Group Presets

- `gitignore`: a `.gitignore` collection from https://github.com/github/gitignore
    - this group is not presented in picker by default, because there's too many of them, use `:NewItem gitignore` to create one.
- `dotnet`: some wrappers for `dotnet new` templates.
