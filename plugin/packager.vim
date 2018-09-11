if exists('g:loaded_vim_packager')
  finish
endif
let g:loaded_vim_packager = 1

function packager#init(...) abort
  if !exists('g:packager')
    let g:packager = packager#new(a:0 > 0 ? a:1 : {})
  endif
  return g:packager
endfunction

function! packager#add(name, ...) abort
  call packager#init()
  return g:packager.add(a:name, a:000)
endfunction

function! packager#install(...) abort
  call packager#init()
  return g:packager.install(a:0 > 0 ? a:1 : {})
endfunction

function! packager#update(...) abort
  call packager#init()
  return g:packager.update(a:0 > 0 ? a:1 : {})
endfunction

function! packager#clean() abort
  call packager#init()
  return g:packager.clean()
endfunction

function! packager#status() abort
  call packager#init()
  return g:packager.status()
endfunction

