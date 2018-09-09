let s:plugin = {}
let s:defaults = { 'dir': '', 'url': '', 'name': '', 'type': 'start', 'package_dir': '',
      \ 'branch': '', 'installed': 0, 'updated': 0, 'rev': '', 'do': '' }

function! packager#plugin#new(name, opts, package_dir) abort
  return s:plugin.new(a:name, a:opts, a:package_dir)
endfunction

function! s:plugin.new(name, opts, package_dir) abort
  let l:instance = extend(copy(self), extend(copy(get(a:opts, 0, {})), s:defaults, 'keep'))
  let l:instance.package_dir = a:package_dir
  let l:instance.name = !empty(l:instance.name) ? l:instance.name : split(a:name, '/')[-1]
  let l:instance.dir = !empty(l:instance.dir) ? fnamemodify(l:instance.dir, ':p') : printf('%s/%s/%s', a:package_dir, l:instance.type, l:instance.name)
  let l:instance.url = a:name =~? '^http.*' ? a:name : printf('https://github.com/%s', a:name)
  if isdirectory(l:instance.dir)
    let l:instance.installed = 1
    let l:instance.rev = l:instance.revision()
  endif
  return l:instance
endfunction

function! s:plugin.update_status(status, text) abort
  if getbufvar(bufname('%'), '&filetype') !=? 'packager'
    return
  endif
  let l:icon = { 'ok': '✓', 'error': '✗', 'progress': '+' }
  let l:existing_line = search(printf('\(%s\)\s%s', join(values(l:icon), '\|'), self.name), 'n')
  if l:existing_line > 0
    let self.line = l:existing_line
    return setline(self.line, printf('%s %s - %s', l:icon[a:status], self.name, a:text))
  endif

  return append(2, printf('%s %s - %s', l:icon[a:status], self.name, a:text))
endfunction

function! s:plugin.git_command(depth) abort
  if isdirectory(self.dir)
    return ['git', '-C', self.dir, 'pull', '--ff-only', '--progress']
  endif
  return ['git', 'clone', '--progress', self.url, self.dir, '--depth', a:depth]
endfunction

function! s:plugin.has_updates() abort
  return !empty(self.rev) && self.rev !=? self.revision()
endfunction

function! s:plugin.revision() abort
  return get(packager#utils#system(['git', '-C', self.dir, 'rev-parse', 'HEAD']), 1, '')
endfunction

function! s:plugin.update_install_status() abort
  if !self.installed
    let self.installed = 1
    let self.updated = 1
    return self.update_status('ok', 'Installed!')
  endif

  if self.has_updates()
    let self.updated = 1
    return self.update_status('ok', 'Updated!')
  endif

  return self.update_status('ok', 'Already up to date.')
endfunction
