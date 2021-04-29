if exists('g:loaded_vim_packager')
  finish
endif
let g:loaded_vim_packager = 1

function packager#init(...) abort
  let s:packager = packager#new(a:0 > 0 ? a:1 : {})
endfunction

function! packager#add(name, ...) abort
  call s:ensure_init()
  call s:packager.add(a:name, get(a:, 1, {}))
endfunction

function! packager#local(name, ...) abort
  call s:ensure_init()
  call s:packager.local(a:name, get(a:, 1, {}))
endfunction

function! packager#install(...) abort
  call s:ensure_init()
  call s:packager.install(a:0 > 0 ? a:1 : {})
endfunction

function! packager#update(...) abort
  call s:ensure_init()
  call s:packager.update(a:0 > 0 ? a:1 : {})
endfunction

function! packager#clean() abort
  call s:ensure_init()
  call s:packager.clean()
endfunction

function! packager#status() abort
  call s:ensure_init()
  call s:packager.status()
endfunction

function! packager#plugins() abort
  call s:ensure_init()
  return s:packager.get_plugins()
endfunction

function! packager#plugin_names() abort
  call s:ensure_init()
  return s:packager.get_plugin_names()
endfunction

function! packager#plugin(name) abort
  call s:ensure_init()
  return s:packager.get_plugin(a:name)
endfunction

function! s:ensure_init()
  if !exists('s:packager')
    return packager#init()
  endif
  return s:packager
endfunction

function! s:call_packager_method(method, ...) abort
  if a:0 > 0
    return s:packager[a:method](a:1)
  endif

  return s:packager[a:method]()
endfunction

function! packager#setup(callback, ...) abort
  let l:opts = get(a:, 1, {})
  if empty(a:callback)
    throw 'Provide valid callback to packager setup via string or funcref.'
  endif
  if type(a:callback) !=? '' && type(a:callback) !=? type(function('tr'))
    throw 'Packager callback must be a string or a funcref/function.'
  endif

  if type(a:callback) ==? type('') && !exists('*'.a:callback)
    throw 'packager function '.a:callback.' does not exist. Try providing a function or funcref.'
  endif

  let s:callback = type(a:callback) ==? type('') ? funcref(a:callback) : a:callback
  let s:opts = get(a:, 1, {})

  command! -nargs=* -bar PackagerInstall call s:run_cmd('install', <args>)
  command! -nargs=* -bar PackagerUpdate call s:run_cmd('update', <args>)
  command! -bar PackagerClean call s:run_cmd('clean', <args>)
  command! -bar PackagerStatus call s:run_cmd('status', <args>)
endfunction

function! s:run_cmd(name, ...)
  call packager#init(s:opts)
  call s:callback(s:packager)
  let l:args = []
  if a:name ==? 'install' || a:name ==? 'update'
    let l:args = [get(a:, 1, {})]
  endif

  return call('packager#'.a:name, l:args)
endfunction

nnoremap <silent> <Plug>(PackagerQuit) :<C-u>call <sid>call_packager_method('quit')<CR>
nnoremap <silent> <Plug>(PackagerOpenSha) :<C-u>call <sid>call_packager_method('open_sha')<CR>
nnoremap <silent> <Plug>(PackagerOpenStdout) :<C-u>call <sid>call_packager_method('open_stdout')<CR>
nnoremap <silent> <Plug>(PackagerGotoNextPlugin) :<C-u>call <sid>call_packager_method('goto_plugin' ,'next')<CR>
nnoremap <silent> <Plug>(PackagerGotoPrevPlugin) :<C-u>call <sid>call_packager_method('goto_plugin', 'previous')<CR>
nnoremap <silent> <Plug>(PackagerStatus) :<C-u>call <sid>call_packager_method('status')<CR>
nnoremap <silent> <Plug>(PackagerPluginDetails) :<C-u>call <sid>call_packager_method('open_plugin_details')<CR>

augroup packager_on_filetype_group
  autocmd!
augroup END
