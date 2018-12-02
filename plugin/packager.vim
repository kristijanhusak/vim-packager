if exists('g:loaded_vim_packager')
  finish
endif
let g:loaded_vim_packager = 1

function packager#init(...) abort
  let g:packager = packager#new(a:0 > 0 ? a:1 : {})
endfunction

function! packager#add(name, ...) abort
  call s:ensure_init()
  return g:packager.add(a:name, a:000)
endfunction

function! packager#local(name, ...) abort
  call s:ensure_init()
  return g:packager.local(a:name, a:000)
endfunction

function! packager#install(...) abort
  call s:ensure_init()
  return g:packager.install(a:0 > 0 ? a:1 : {})
endfunction

function! packager#update(...) abort
  call s:ensure_init()
  return g:packager.update(a:0 > 0 ? a:1 : {})
endfunction

function! packager#clean() abort
  call s:ensure_init()
  return g:packager.clean()
endfunction

function! packager#status() abort
  call s:ensure_init()
  return g:packager.status()
endfunction

function! s:ensure_init()
  if !exists('g:packager')
    return packager#init()
  endif
  return g:packager
endfunction
