local file = require('new-item.items').FileItem
local cmd = require('new-item.items').CmdItem
local U = require('new-item.util')
return {
  cmd {
    id = 'tsconfig',
    label = 'tsconfig.json',
    exe = U.exe_from_node_modules('tsc'),
    args = { '--init' },
    nameable = false,
    default_name = 'tsconfig.json',
  },
}
