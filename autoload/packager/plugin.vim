let s:plugin = {}
let s:defaults = { 'name': '', 'type': 'start', 'branch': '', 'commit': '', 'tag': '',
      \ 'installed': 0, 'updated': 0, 'rev': '', 'do': '', 'last_update': [], 'frozen': 0 }

function! packager#plugin#new(name, opts, packager) abort
  return s:plugin.new(a:name, a:opts, a:packager)
endfunction

function! s:plugin.new(name, opts, packager) abort
  let l:instance = extend(copy(self), extend(copy(get(a:opts, 0, {})), s:defaults, 'keep'))
  let l:instance.packager = a:packager
  let l:instance.name = !empty(l:instance.name) ? l:instance.name : split(a:name, '/')[-1]
  let l:instance.dir = printf('%s/%s/%s', a:packager.dir, l:instance.type, l:instance.name)
  let l:instance.url = a:name =~? '^http.*' ? a:name : printf('https://github.com/%s', a:name)
  if isdirectory(l:instance.dir)
    let l:instance.installed = 1
    let l:instance.rev = l:instance.revision()
    let l:instance.last_update = l:instance.get_last_update()
  endif
  return l:instance
endfunction

function! s:plugin.update_status(status, text) abort
  if getbufvar(bufname('%'), '&filetype') !=? 'packager'
    return
  endif
  let l:icons = join(values(packager#utils#status_icons()), '\|')
  let l:existing_line = search(printf('\(%s\)\s%s\s—', l:icons, self.name), 'n')
  if l:existing_line > 0
    let self.line = l:existing_line
    return setline(self.line, packager#utils#status(a:status, self.name, a:text))
  endif

  return append(2, packager#utils#status(a:status, self.name, a:text))
endfunction

function! s:plugin.update_git_command() abort
  let l:update_cmd = ['cd', self.dir, '&&', 'git', 'pull', '--ff-only', '--progress']

  for l:checkout_target in [self.commit, self.tag]
    if !empty(l:checkout_target)
      return l:update_cmd + ['&&', 'git', 'checkout', l:checkout_target]
    endif
  endfor

  return l:update_cmd
endfunction

function! s:plugin.install_git_command(depth) abort
  let l:requires_checkout = !empty(self.tag) || !empty(self.commit)
  let l:depth = l:requires_checkout ? '999999' : a:depth
  let l:clone_cmd = ['git', 'clone', '--progress', self.url, self.dir, '--depth', l:depth]

  if !empty(self.branch) && !l:requires_checkout
    let l:clone_cmd += ['--branch', self.branch]
  endif

  if l:requires_checkout
    let l:clone_cmd += ['&&', 'cd', self.dir]
  endif

  for l:checkout_target in [self.commit, self.tag]
    if !empty(l:checkout_target)
      return l:clone_cmd + ['&&', 'git', 'checkout', l:checkout_target]
    endif
  endfor

  return l:clone_cmd
endfunction

function! s:plugin.git_command(depth) abort
  if isdirectory(self.dir)
    return join(self.update_git_command(), ' ')
  endif

  return join(self.install_git_command(a:depth), ' ')
endfunction

function! s:plugin.has_updates() abort
  return !empty(self.rev) && self.rev !=? self.revision()
endfunction

function! s:plugin.get_last_update() abort
  let l:commits = packager#utils#system(['git', '-C', self.dir, 'log',
        \ '--color=never', '--pretty=format:"%h %s (%cr)"', '--no-show-signature', 'HEAD@{1}..'
        \ ])

  return filter(l:commits, 'v:val !=? "" && v:val !~? "^fatal"')
endfunction

function! s:plugin.revision() abort
  let l:rev = get(packager#utils#system(['git', '-C', self.dir, 'rev-parse', 'HEAD']), 0, '')
  if l:rev =~? '^fatal'
    return ''
  endif
  return l:rev
endfunction

function! s:plugin.update_install_status() abort
  if !self.installed
    let self.installed = 1
    let self.updated = 1
    return self.update_status('ok', 'Installed!')
  endif

  if self.has_updates()
    let self.updated = 1
    let self.last_update = self.get_last_update()
    return self.update_status('ok', 'Updated!')
  endif

  return self.update_status('ok', 'Already up to date.')
endfunction
