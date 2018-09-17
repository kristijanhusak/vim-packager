function! packager#utils#system(cmds) abort
  let l:prev = [&shell, &shellcmdflag, &shellredir]
  if has('win32')
    set shell=cmd.exe shellcmdflag=/c shellredir=>%s\ 2>&1
  else
    set shell=sh shellredir=>%s\ 2>&1
  endif
  let l:result = systemlist(join(a:cmds, ' '))
  let [&shell, &shellcmdflag, &shellredir] = l:prev
  return l:result
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
  silent! exe 'redraw'
  try
    let l:confirm = confirm(a:question, "&Yes\n&No")
    return l:confirm ==? 1
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
