scriptencoding utf8
let s:plugin = {}
let s:slash = exists('+shellslash') && !&shellslash ? '\' : '/'
let s:defaults = { 'name': '', 'type': 'start', 'branch': '', 'commit': '', 'tag': '',
      \ 'installed': 0, 'updated': 0, 'rev': '', 'do': '', 'frozen': 0 }

function! packager#plugin#new(name, opts, packager) abort
  return s:plugin.new(a:name, a:opts, a:packager)
endfunction

function! s:plugin.new(name, opts, packager) abort
  let l:instance = extend(copy(self), extend(copy(get(a:opts, 0, {})), s:defaults, 'keep'))
  let l:instance.packager = a:packager
  let l:instance.name = !empty(l:instance.name) ? l:instance.name : split(a:name, '/')[-1]
  let l:instance.dir = printf('%s%s%s%s%s', a:packager.dir, s:slash, l:instance.type, s:slash, l:instance.name)
  let l:instance.local = get(l:instance, 'local', 0)
  let l:instance.url = a:name =~? '^\(http\|git@\).*'
        \ ? a:name
        \ : l:instance.local ? a:name : printf('https://github.com/%s', a:name)
  let l:instance.event_messages = []
  let l:instance.hook_event_messages = []
  let l:instance.update_failed = 0
  let l:instance.hook_failed = 0
  let l:instance.last_update = []
  let l:instance.head_ref = ''
  let l:instance.main_branch = ''
  if isdirectory(l:instance.dir)
    let l:instance.installed = 1
    let l:instance.rev = l:instance.revision()
    let l:instance.last_update = l:instance.get_last_update()
    let l:instance.head_ref = l:instance.get_head_ref()
    let l:instance.main_branch = l:instance.get_main_branch()
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

  return append(3, packager#utils#status(a:status, self.name, a:text))
endfunction

function! s:plugin.update_git_command() abort
  let l:update_cmd = ['cd', self.dir]
  let l:has_checkout = v:false
  let l:is_on_branch = v:true

  for l:checkout_target in [self.commit, self.tag, self.branch]
    if !empty(l:checkout_target)
      let l:update_cmd += ['&&', 'git', 'checkout', l:checkout_target]
      let l:is_on_branch = l:checkout_target ==? self.branch
      let l:has_checkout = v:true
      break
    endif
  endfor

  if !l:has_checkout && self.head_ref ==? 'HEAD' && !empty(self.main_branch)
    let l:is_on_branch = v:true
    let l:update_cmd += ['&&', 'git', 'checkout', self.main_branch]
  endif

  if l:is_on_branch
    let l:update_cmd += ['&&', 'git', 'pull', '--ff-only', '--progress']
  else
    let l:update_cmd += ['&&', 'git', 'fetch', self.url]
  endif
  let l:update_cmd += ['&&', 'git', 'submodule', 'update', '--init', '--recursive', '--progress']

  return l:update_cmd
endfunction

function! s:plugin.install_git_command(depth) abort
  let l:requires_checkout = !empty(self.tag) || !empty(self.commit)
  let l:depth = l:requires_checkout ? '999999' : a:depth
  let l:clone_cmd = ['git', 'clone', '--progress', self.url, self.dir, '--depth', l:depth]

  if !empty(self.branch) && !l:requires_checkout
    let l:clone_cmd += ['--branch', self.branch]
  endif

  let l:clone_cmd += ['&&', 'cd', self.dir]
  let l:clone_cmd += ['&&', 'git', 'submodule', 'update', '--init', '--recursive', '--progress']

  for l:checkout_target in [self.commit, self.tag]
    if !empty(l:checkout_target)
      return l:clone_cmd + ['&&', 'git', 'checkout', l:checkout_target]
    endif
  endfor

  return l:clone_cmd
endfunction

function! s:plugin.local_command() abort
  if executable('ln')
    return ['ln', '-s', fnamemodify(self.url, ':p'), self.dir]
  endif

  if has('win32') && executable('mklink')
    return ['mklink', fnamemodify(self.url, ':p'), self.dir]
  endif

  return ['echo', printf('Cannot install %s locally, linking tool not found.', self.name)]
endfunction

function! s:plugin.command(depth) abort
  if isdirectory(self.dir) && !self.local
    return join(self.update_git_command(), ' ')
  endif

  if self.local
    return join(self.local_command())
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

function! s:plugin.get_head_ref() abort
  let l:head = get(packager#utils#system(['git', '-C', self.dir, 'rev-parse', '--abbrev-ref', 'HEAD']), 0, '')
  if l:head =~? '^fatal'
    return ''
  endif

  return l:head
endfunction

function! s:plugin.get_main_branch() abort
  let l:ref = get(packager#utils#system(['git', '-C', self.dir, 'symbolic-ref', 'refs/remotes/origin/HEAD']), 0, '')
  if l:ref =~? '^fatal'
    return ''
  endif

  return split(l:ref, '/')[-1]
endfunction

function! s:plugin.update_install_status() abort
  if !self.installed
    let self.installed = 1
    let self.updated = 1
    return 'Installed!'
  endif

  if self.has_updates()
    let self.updated = 1
    let self.last_update = self.get_last_update()
    return 'Updated!'
  endif

  return 'Already up to date.'
endfunction

function! s:plugin.get_message_key(is_hook) abort
  if a:is_hook
    return 'hook_event_messages'
  endif

  return 'event_messages'
endfunction

function! s:plugin.log_event_messages(event, messages, ...) abort
  if a:event ==? 'exit'
    return 0
  endif
  let l:key = self.get_message_key(a:0 > 0)

  if type(a:messages) ==? type([])
    for l:message in a:messages
      if !empty(packager#utils#trim(l:message)) && index(self[l:key], l:message) < 0
        call add(self[l:key], l:message)
      endif
    endfor
  endif

  if type(a:messages) ==? type('') && index(self[l:key], a:messages) < 0
    call add(self[l:key], a:messages)
  endif
endfunction

function! s:plugin.get_last_progress_message(...) abort
  let l:key = self.get_message_key(a:0 > 0)
  let l:last_msg = get(self[l:key], -1, '')
  return get(split(l:last_msg, '\r'), -1, l:last_msg)
endfunction

function! s:plugin.get_short_error_message(...) abort
  let l:is_hook = a:0 > 0
  let l:key = self.get_message_key(l:is_hook)
  return packager#utils#trim(get(self[l:key], -1, ''))
endfunction

function! s:plugin.get_stdout_messages() abort
  let l:result = []
  let l:key = self.get_message_key(self.hook_failed)

  for l:message in self[l:key]
    let l:split_message = split(l:message, '\r')
    for l:msg in l:split_message
      if !empty(packager#utils#trim(l:msg))
        call add(l:result, l:msg)
      endif
    endfor
  endfor

  return l:result
endfunction

function! s:plugin.get_content_for_status() abort
  if !self.installed
    let l:err_msg = self.get_short_error_message()
    let l:last_err_line = !empty(l:err_msg) ? ' Last line of error message:' : ''
    let l:status = printf('Not installed.%s', l:last_err_line)
    let l:result = [packager#utils#status_error(self.name, l:status)]
    if !empty(l:err_msg)
      call add(l:result, printf('  * %s', l:err_msg))
    endif
    return l:result
  endif

  if self.update_failed
    return [packager#utils#status_error(self.name, 'Install/update failed. Last line of error message:'),
          \ printf('  * %s', self.get_short_error_message())]
  endif

  if self.hook_failed
    return [packager#utils#status_error(self.name, 'Post hook failed. Last line of error message:'),
          \ printf('  * %s', self.get_short_error_message('hook'))]
  endif

  if empty(self.last_update)
    return [packager#utils#status_ok(self.name, 'OK.')]
  endif

  let l:result = [packager#utils#status_ok(self.name, 'Updated.')]
  for l:update in self.last_update
    call add(l:result, printf('  * %s', l:update))
  endfor
  return l:result
endfunction
