function! packager#utils#system(cmds) abort
  let l:out = []
  let l:job = packager#job#start(a:cmds,
        \ {'on_stdout': {id, mes, ev -> extend(l:out, mes)}})
  if l:job > 0
    let l:ret = packager#job#wait([l:job])[0]
    sleep 5m
  endif
  return [l:ret, l:out]
endfunction
