if exists('g:loaded_vim_packager')
  finish
endif
let g:loaded_vim_packager = 1

function packager#init(...) abort
  if !exists('s:packager')
    let s:packager = packager#new(a:1)
  endif
  return s:packager
endfunction

function! packager#quit() abort
  call packager#init()
  return s:packager.quit()
endfunction

function! packager#add(name, ...) abort
  call packager#init()
  return s:packager.add(a:name, a:000)
endfunction

function! packager#install() abort
  call packager#init()
  return s:packager.install()
endfunction

