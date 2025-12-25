# Documentation

## Preface

### Conventions

Examples in this documentation assumes the following variables available in context.

```lua
local file = require('new-item.items').FileItem
local cmd = require('new-item.items').CmdItem
local groups = require('new-item.groups')
```

### Two Ways of Declaration

Note that this documentation primarily uses a imperative style because it can imply more details about the context.
However, both declarative and imperative style are available using `new-item.Config.setup`, you can pick one preferred.
Some action might require imperative style anyway(overriding item for example).

> [!NOTE]
> `new-item.Config.setup.groups` is initialized before the invocation of `new-item.Config.setup.init`.

```lua
local file = require('new-item.items').FileItem
local cmd = require('new-item.items').CmdItem

require('new-item').setup {
  -- declarative style
  groups = {
    my_group = {
      visible = true,
      items = {
        file { ... }
        cmd { ... }
      }
    }
  },
  -- imperative style
  init = function(groups, ctors)
    groups.my_group = {
      visible = true,
      items = {
        ctors.file { ... }
        ctors.cmd { ... }
      }
    }
  end
}
```

## Item & Item Group

An **Item** is a template knows how to create a thing, an `ItemGroup` is a dynamically conditioned container for items.
This plugin was written in a object-oriented style, each type of item was derived from `new-item.Item`, any kind of item has the following fields:

- `id`: identifier for the item.
- `suffix` and `prefix`: parts around the name of item.
    - for example, to create a typescript test file, the `suffix` can be `.test.ts`, and the final name would be `<name>.test.ts`.
- `nameable`: indicating whether the item can have a custom name.
    - for example, a `.gitignore` is always `.gitignore`, it should be not `nameable`.
    - if an item is not `nameable`, it must have a `default_name`.
- `default_name`: a default value for the name, can evaluate dynamically.
    - `default_name` is the pre-filled input of `vim.ui.input` during creation when the item is `nameable`.
- `cwd`: the folder where the item would be created at, **defaults to parent of current buffer.**
- `edit`: presume the item created is a file, and open it after creation.
- `extra_args`: a key-value pair of argument specification, each argument will have an input request during creation.
    - You can access these argument values in `ctx` of each phase
    - `CmdItem` will generate special variables like `$ITEM_<uppercase_name>` to interpolate in `CmdItem.cmd`
- `before_create(item, ctx)`: to perform a transformation before actually creating the item
    - you may transform things like the content or path, even the item template itself(it's an copy of original one)
- `after_create(item, ctx)`: to perform after creation

<details>
<summary>Item base definition</summary>

```lua
---@class new-item.Item
---@field label string Name displayed as entry in picker
---@field desc? string Description of the item
---@field invoke? fun(self: self) Activate the creation for this item
---@field cwd? fun(): string Returns which parent folder to create the file, default to parent of current buffer
---@field extra_args? string[] Extra argument names to be specified on creation
---@field before_create? fun(self: new-item.AnyItem, ctx: new-item.ItemCreationContext)
---@field after_create? fun(self: new-item.AnyItem, ctx: new-item.ItemCreationContext)
---@field nameable? boolean True if the file item should have a custom name on creation
---@field default_name? string | fun(): string Default name of the item to be created
---@field suffix? string Trailing content of the constructed item name. Can be file extension such as `.lua` or suffix like `.test.ts`
---@field prefix? string Leading content of the constructed item name
```

</details>

### Writing Items

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
groups.javascript:append { -- assuming javascript is a existing item group
  file {
    id = 'javascript',
    label = 'javascript file',
    content = 'console.log("%s")', -- %s will be replaced by name input
    filetype = 'javascript', -- for treesitter highlighting
    suffix = '.js' -- extension of the file
  }
  file {
    id = 'prettierrc',
    label = '.prettierrc',
    edit = false, -- do not create the file directly but open a buffer with content
    link = vim.fn.expand('~/.prettierrc'), -- use content of an existing file
    nameable = false, -- .prettierrc is always .prettierrc
    default_name = '.prettierrc',
    filetype = 'json',
    cwd = function() return vim.fn.getcwd() end, -- should always add to project root
  },
}
groups.md:append {
  -- use the file name as top level title
  file {
    id = 'markdown',
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
---@field env? table<string, string> environment variables
---@overload fun(o: new-item.CmdItem): new-item.CmdItem
```

</details>

`new-item.CmdItem` has special variables available to be expanded in `CmdItem.cmd` field.
- `$ITEM_NAME`: equivalent to `ctx.name_input` or `item.default_name`
- `$ITEM_CWD`: equivalent to `ctx.cwd`
- `$ITEM_SUFFIX`: equivalent to `item.suffix`
- `$ITEM_PREFIX`: equivalent to `item.prefix`
- `$ITEM_<uppercase_name>`: equivalent to values of `ctx.args`(in uppercase)

The following examples shows how it wrap `dotnet new` command as a template.

```lua
groups.dotnet:append {
  cmd {
    id = 'buildtargets',
    label = 'Directory.Build.targets',
    nameable = false,
    default_name = 'Directory.Build.targets',
    cmd = { 'dotnet', 'new', 'buildtargets' },
  },
  cmd {
    id = 'slnx',
    label = 'slnx',
    cmd = { 'dotnet', 'new', 'sln', '--format', 'slnx', '--name', '$ITEM_NAME' },
    suffix = '.slnx',
    default_name = function() return vim.fs.basename(vim.fn.getcwd()) end, -- use root folder name as default
  }
}
```

#### Using Transformation

You can transform  `item` and `ctx` on `before_create` to let it be a context-aware template.
A context contains temporary values generated during the creation, such as `name_input`, `cwd` etc.

<details>
<summary>ItemCreationContext definition</summary>

```lua
---@class new-item.ItemCreationContext
---@field name_input? string name specified from vim.ui.input
---@field args? table<string, string> args input from vim.ui.input
---@field path? string path of the item to be created
---@field cwd? string the folder where the item would be created at
---@field buf? integer the buffer number created for the item
```

</details>

The following example shows how to use a `FileItem` create a new `C#` class using its current folder structure as namespace.

```lua
groups.dotnet:append {
  file {
    label = 'class',
    suffix = '.cs',
    filetype = 'cs',
    content = vim.text.dedent(0, [[
    namespace <namespace>;
    public class %s { }
    ]]),
    before_create = function(item, ctx)
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

#### Using Extra Args

`item.extra_args` are arguments other than input name, to be specified during prompt.
You can set a default value and description for the prompt.

```lua
---@class new-item.ItemCreationArgument
---@field default? string | fun(): string
---@field desc? string
```

`item.extra_args` is available for all item types, you can access those argument values from `ctx.args` after prompt.
Each name of the args will generate a corresponding variable `$ITEM_<uppercase_name>` to be expanded in `CmdItem.cmd`.

```lua
cmd {
  -- ...
  cmd = {
    'dotnet',
    'new',
    'global.json'
    '--sdk-version',
    '$ITEM_SDK_VERSION', -- access the special value in uppercase
  },
  extra_args = {
    sdk_version = { -- this name will generate a special variable
      desc = '--sdk-version',
      default = function()
        return vim.trim(vim.fn.system { 'dotnet', '--version' })
      end
    },
  },
  before_create = function(item, ctx)
    _ = ctx.args.sdk_version -- you may access it from ctx
  end
}
```

#### Override Item

`group.<id>:override` allows to modify the item specification with `final` and `prev` states.
`final` is the current state of the item(to be modified), `prev` is the original state of the item.
The following example is how you can append extra operation to `before_create` phase of item `buildprops`, from `dotnet` group.

```lua
groups.dotnet.buildprops:override(function(final, prev)
  final.before_create = function(item, ctx)
    -- additional operations...
    prev.before_create(item, ctx)
  end
end)
```

If loading a group involves asynchronous operation, you would need to bind a callback using `ItemGroup.on_loaded` to do the override.

```lua
groups.dotnet:on_loaded(function(self)
  self.buildprops:override(function(final, prev)
    final.before_create = function(item, ctx)
      -- additional operations...
      prev.before_create(item, ctx)
    end
  end)
end)
```

### Writing ItemGroup

Each item must be of certain group, each group has a `visible` field to be evaluated dynamically to indicate whether its contained items should present each time your invoke the picker.

- `visible(): boolean`: indicating whether its items should present in picker.
- `items`: user-defined templates.
- `append(self, items)`: append extra templates to `itemgroup.items` list.

For example, you may require javascript templates to present only when it found a `package.json` file on root.

```lua
groups.javascript = {
  visible = function()
    return vim.fs.root(vim.fn.expand('%:p:h'), 'package.json') ~= nil
  end,
  items = {--[[...]]}
}
```

You can add any number of groups for your specific working environments.

#### Override ItemGroup

`ItemGroup` was designed as a proxy table, so it has a dedicated method `ItemGroup:override` to alter its state.
That is, do not assign or alter any field to an `ItemGroup` with dot accessor, use `override` instead.

```lua
group:override {
  visible = true,
}
```

### Writing ItemSource

```lua
---@class new-item.ItemSource
---@field [1] string | fun(add_items: fun(items: new-item.AnyItem[])): new-item.AnyItem[]?
---@field name string
```

An `ItemSource` can presented as three kinds of data type with `name` as its identifier.

- Module name: a module that returns a list of items.
- Function: a function returns a list of items.
- Function with callback: a function uses a callback to add items, useful for asynchronous scenarios.

```lua
---@class new-item.ItemSource
---@field [1] string | fun(add_items: fun(items: new-item.AnyItem[])): new-item.AnyItem[]?
---@field name string

groups.my_group = {
  sources = {
    { name = 'foo', 'new-item.foo' },
    {
        name = 'bar',
        function()
          -- return a list of items
          return { file { ... }, cmd { ... } }
        end,
    },
    {
      name = 'baz',
     function(add_items)
       -- add_items(items) is a callback to add items to the group
       do_something_with_callback(add_items)
     end
    },
  }
}
```

### How does it work

1. An item name was decided by either `ctx.name_input` or `default_name`, depending on whether the template is `nameable`.
2. Path of the item to be created was formatted as the `${ctx.cwd}/${item.prefix}${ctx.name_input ?? item.default_name}${item.prefix}`
3. `before_create` was then triggered, might perform some transformation.
4. `item:invoke()` was triggered to create the item.
5. `after_create` was triggered to perform a post action.
