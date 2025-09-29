local file = require('new-item.items').FileItem
local cmd = require('new-item.items').CmdItem
return {
  cmd {
    iname = 'tsconfig',
    label = 'tsconfig.json',
    cmd = { 'tsc', '--init' },
    nameable = false,
    default_name = 'tsconfig.json',
    before_creation = function(item, ctx)
      if
        #vim.fs.find(
          { 'bun.lock', 'bun.lockb' },
          { limit = 1, type = 'file', path = ctx.cwd }
        ) > 0
      then
        item.cmd = vim.list_extend({ 'bun' }, item.cmd)
      elseif
        #vim.fs.find({ 'package.json' }, { limit = 1, type = 'file', path = ctx.cwd })
        > 0
      then
        item.cmd = vim.list_extend({ 'npx' }, item.cmd)
      elseif
        #vim.fs.find(
          { 'deno.json', 'deno.jsonc' },
          { limit = 1, type = 'file', path = ctx.cwd }
        ) > 0
      then
        item.cmd = vim.list_extend({ 'deno' }, item.cmd)
      end
    end,
  },
}
