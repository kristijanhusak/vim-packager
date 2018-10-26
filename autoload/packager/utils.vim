function! packager#utils#system(cmds) abort
  let l:save_shell = packager#utils#set_shell()
  let l:cmd_output = systemlist(join(a:cmds, ' '))
  call packager#utils#restore_shell(l:save_shell)
  return l:cmd_output
endfunction

function! packager#utils#status_ok(name, status_text)
  return packager#utils#status('ok', a:name, a:status_text)
endfunction

function! packager#utils#status_progress(name, status_text)
  return packager#utils#status('progress', a:name, a:status_text)
endfunction

function! packager#utils#status_error(name, status_text)
  return packager#utils#status('error', a:name, a:status_text)
endfunction

function! packager#utils#status_icons()
  return { 'ok': '✓', 'error': '✗', 'progress': '+' }
endfunction

function! packager#utils#status(icon, name, status_text) abort
  let l:icons = packager#utils#status_icons()
  return printf('%s %s — %s', l:icons[a:icon], a:name, a:status_text)
endfunction

function! packager#utils#confirm(question) abort
  let l:confirm = packager#utils#confirm_with_options(a:question, "&Yes\nNo")
  return l:confirm ==? 1
endfunction

function! packager#utils#confirm_with_options(question, options) abort
  silent! exe 'redraw'
  try
    let l:option = confirm(a:question, a:options)
    return l:option
  catch
    return 0
  endtry
endfunction

function! packager#utils#add_rtp(path) abort
  if empty(&runtimepath)
    let &runtimepath = a:path
  else
    let &runtimepath .= printf(',%s', a:path)
  endif
endfunction

function! packager#utils#trim(str) abort
  return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! packager#utils#check_support() abort
  if !has('packages')
    throw '"packages" feature not supported by this version of (Neo)Vim.'
  endif

  if !has('nvim') && !has('job')
    throw '"jobs" feature not supported by this version of (Neo)Vim.'
  endif
endfunction

function! packager#utils#set_shell() abort
  let l:save_shell = [&shell, &shellcmdflag, &shellredir]

  if has('win32')
    set shell=cmd.exe shellcmdflag=/c shellredir=>%s\ 2>&1
  else
    set shell=sh shellredir=>%s\ 2>&1
  endif

  return l:save_shell
endfunction

function! packager#utils#restore_shell(saved_shell) abort
  let [&shell, &shellcmdflag, &shellredir] = a:saved_shell
endfunction

function! packager#utils#load_plugin(plugin) abort
  call packager#utils#add_rtp(a:plugin.dir)
  for l:path in ['plugin/**/*.vim', 'after/plugin/**/*.vim']
    let l:full_path = printf('%s/%s', a:plugin.dir, l:path)
    if !empty(glob(l:full_path))
      silent exe 'source '.l:full_path
    endif
  endfor
endfunction
