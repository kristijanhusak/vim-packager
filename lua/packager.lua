local packager = {}
local callback = nil
local options = nil

function packager.setup(cb, opts)
  callback = cb
  options = opts or vim.empty_dict()

  vim.cmd [[command! -nargs=* -bar PackagerInstall call luaeval("require'packager'.run_cmd('install', _A)", <args>) ]]
  vim.cmd [[command! -nargs=* -bar PackagerUpdate call luaeval("require'packager'.run_cmd('update', _A)", <args>) ]]
  vim.cmd [[command! -bar PackagerClean lua require'packager'.run_cmd('clean')]]
  vim.cmd [[command! -bar PackagerStatus lua require'packager'.run_cmd('status')]]
end

function packager.run_cmd(name, args)
  vim.fn['packager#init'](options)
  callback({
    add = vim.fn['packager#add'],
    ['local'] = vim.fn['packager#local']
  })

  if name == 'install' or name == 'update' then
    return vim.fn['packager#'..name](args or vim.empty_dict())
  end

  return vim.fn['packager#'..name]()
end

return packager
