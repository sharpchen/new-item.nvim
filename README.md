# new-item.nvim

Creating items from context-aware templates.

![new-item](https://github.com/user-attachments/assets/ed260dea-a3b9-4063-a540-66b9cf7b0f68)

## Why this plugin

The idea came from the common feature of modern IDEs that, allowing to create a file based on template and context, things like **Add new class** in the menu while you right-click in the explorer.
This plugin was designed to be a **scaffold** to write your own template with context-aware capabilities.

## Features

- Wrapping templates declaratively for file or shell command.
- Context-aware with phases available for each template item.
- Dynamic/customizable visibility for groups, matching for your working environment.
- Allows overriding existing groups/items.
- Allows to import external item sources to your groups.
- Reloads on `Config.setup` and `DirChanged` automatically.
- Supports picking items using `vim.ui.select` or pickers([snacks.nvim](https://github.com/folke/snacks.nvim), [fzf-lua](https://github.com/ibhagwan/fzf-lua) or [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)) with preview.

## Setup

- [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'sharpchen/new-item.nvim',
  event = 'VeryLazy',
  submodules = true,
  config = function()
    require('new-item').setup {
      groups = {
        my_group = {
          visible = function() return ... end, -- your dynamic condition for the group
          items = { ... } -- write your template items here
          sources = { ... } -- or import template items from sources
        }
      }
    }
    vim.keymap.set('n', '<leader>ni', '<cmd>NewItem<CR>')
  end
}
```

### Default Config

<details>
<summary>click to expand</summary>

```lua
---@class (exact) new-item.Config
---@field picker new-item.PickerConfig | fun(items: new-item.AnyItem[]) picker for selecting item
---@field init? fun(groups: table<string, new-item.ItemGroup>, ctors: { file: new-item.FileItem, cmd: new-item.CmdItem })
---@field groups? table<string, Partial<new-item.ItemGroup>>
---@field transform_path? fun(path: string): string Global transformer for constructed path
---@field default_cwd? fun(): string? Return nil if current evaluation should be terminated
M.config = {
  picker = {
    name = 'select',
    preview = false,
    entry_format = function(group, item)
      return string.format('[%s] %s', group.name, item.label)
    end,
  },
  init = nil,
  transform_path = function(path) return path:gsub('^oil:', '') end,
  default_cwd = function()
    local path = vim.fs.dirname(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
    -- unnamed buffer and scratch buffer have parent '.'
    -- convert it to absolute path
    if path == '.' then path = vim.uv.cwd() end
    return path
  end,
  groups = { },
}
```

</details>

## Quick Start

### Try Out Presets

If you currently don't have any idea for writing a template, you can try out presets. See [using presets](#using-presets)

### Command

- `:NewItem`: prompt a picker with candidate items that are *visible in current environment*.
- `:NewItem <group>`: pick an item from candidates of the group
- `:NewItem <group> <item>`: invoke certain item from group.
- `:NewItemReload`: forcibly reload sources of all *visible* groups

### Writing Groups

A group describes how its child items(templates) can be presented as candidates in current environment.
In general we recommend to construct groups on users' own, templates are either wrapped as sources to be added/declared in the group specification, or added as unbundled items to `ItemGroup.items`.
For example, you may require javascript templates to present only when it found a `package.json` file on root.
Similarly, you would expect to present `dotnet` templates only when it found a `.*proj` or solution file.

> [!TIP]
> See [writing-itemgroup](/DOCUMENTATION.md#writing-itemgroup)

```lua
require('new-item').setup {
  groups = {
    javascript = {
      visible = function()
        return vim.fs.root(vim.fn.expand('%:p:h'), 'package.json') ~= nil
      end,
      items = { ... }
    },
    dotnet = {
      visible = function()
        return vim.fs.root(
          vim.fn.expand('%:p:h'),
          function(name, _) return name:match('%.slnx?$') or name:match('%.%w+proj$') end
        ) ~= nil
      end,
      sources = { -- add items from sources
        {
          name = 'builtin',
          { ... }
        },
      },
    }
  }
}
```

### Writing Item

There's two major item type you can construct out-of-box, `new-item.FileItem` is to create file/buffer with string content/existing file, `new-item.CmdItem` is for creating file from shell command.
You can try the following example to have a initial perception of the usage, see [writing-items](/DOCUMENTATION.md#writing-items) for more concrete examples.

```lua
local file = require('new-item.items').FileItem
local cmd = require('new-item.items').CmdItem

-- to create parent_of_current_buf/foo.txt
local examplefile = file {
  id = 'example',
  label = 'Example file',
  suffix = '.txt',
  content = 'This is an example',
}
-- NOTE: of course you don't need invoke() when using picker
-- this just exemplify a minimal usage
examplefile:invoke() -- open the buffer with content set

-- or create it using shell command
local examplefile_by_command = cmd {
  id = 'example',
  label = 'Example file',
  suffix = '.txt',
  cmd = { 'touch', '$ITEM_NAME.txt' },
  after_create = function(_, ctx)
    vim.fn.setbufline(ctx.buf, 1, { 'This is an example' })
  end
}

examplefile_by_command:invoke() -- creates the file
```

You can add these custom template items to specific groups using `new-item.Config.groups`

```lua
local file = require('new-item.items').FileItem
local cmd = require('new-item.items').CmdItem

require('new-item').setup {
  groups = {
    my_group = {
      visible = true,
      items = {
        file { ... }
        cmd { ... }
      }
    }
  }
}
```


### Override Items

It's possible to modify existing items to get it fit with your use. See: [override-item](/DOCUMENTATION.md#override-item)

## Using Presets

### Gitignore & Gitattributes Preset

To use community templates from [gitignore collection](https://github.com/github/gitignore) and [gitattributes collection](https://github.com/gitattributes/gitattributes), see the following lazy.nvim example.
Note that `visible = false` is recommended for these templates because there's too many of them, and adding such file is fairly infrequent.
You should manually call `:NewItem gitignore` to create one.

```lua
{
  dependencies = {
    'github/gitignore',
    'gitattributes/gitattributes',
  },
  config = function()
    require('new-item').setup {
      groups = {
        gitignore = {
          visible = false,
          sources = {
            {
              name = 'new-item',
              function() return require('new-item.groups.gitignore')() end,
            },
          },
        },
        gitattributes = {
          visible = false,
          sources = {
            {
              name = 'new-item',
              function() return require('new-item.groups.gitattributes')() end,
            },
          },
        },
      },
    }
  end
}
```

> [!NOTE]
> If you installed the gitattributes/gitignore collection in a non-default name, you can pass the name to `require('new-item.groups.gitattributes')(name)`

### Dotnet Preset

Preset items for `dotnet new <template>` are currently managed within the plugin itself, you don't have to configure anything but requires `dotnet` cli(.NET Core).

