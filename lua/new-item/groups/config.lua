local file = require('new-item.items').FileItem
local cmd = require('new-item.items').CmdItem
return {
  cmd {
    id = 'tsconfig',
    label = 'tsconfig.json',
    -- FIXME: make node dedicated exe finder
    exe = 'tsc',
    args = { 'tsc', '--init' },
    nameable = false,
    default_name = 'tsconfig.json',
    before_create = function(item, ctx)
      if
        #vim.fs.find(
          { 'bun.lock', 'bun.lockb' },
          { limit = 1, type = 'file', path = ctx.cwd }
        ) > 0
      then
        item.args = vim.list_extend({ 'bun' }, item.args)
      elseif
        #vim.fs.find({ 'package.json' }, { limit = 1, type = 'file', path = ctx.cwd })
        > 0
      then
        item.args = vim.list_extend({ 'npx' }, item.args)
      elseif
        #vim.fs.find(
          { 'deno.json', 'deno.jsonc' },
          { limit = 1, type = 'file', path = ctx.cwd }
        ) > 0
      then
        item.args = vim.list_extend({ 'deno' }, item.args)
      end
    end,
  },
}
