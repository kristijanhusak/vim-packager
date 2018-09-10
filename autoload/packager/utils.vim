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

function! packager#utils#update_remote_plugins(plugins) abort
  for l:plugin in a:plugins
    if l:plugin.updated && isdirectory(printf('%s/rplugin', l:plugin.dir))
      call s:add_rtp(l:plugin.dir)
      exe 'UpdateRemotePlugins'
    endif
  endfor
endfunction

function! s:add_rtp(path)
  if empty(&rtp)
    let &rtp = a:path
  else
    let &rtp .= printf(',%s', a:path)
  endif
endfunction
