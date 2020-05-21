scriptencoding utf8
let s:plugin = {}
let s:is_windows = has('win32')
let s:slash = exists('+shellslash') && !&shellslash ? '\' : '/'
let s:defaults = { 'name': '', 'branch': '', 'commit': '', 'tag': '',
      \ 'installed': 0, 'updated': 0, 'rev': '', 'do': '', 'frozen': 0, 'rtp': '' }

function! packager#plugin#new(name, opts, packager) abort
  return s:plugin.new(a:name, a:opts, a:packager)
endfunction

function! s:plugin.new(name, opts, packager) abort
  let l:instance = extend(copy(self), extend(copy(get(a:opts, 0, {})), s:defaults, 'keep'))
  if !has_key(l:instance, 'type') || empty(l:instance.type)
    let l:instance.type = a:packager.default_plugin_type
  endif
  if index(['opt', 'start'], l:instance.type) <= -1
    let l:instance.type = 'start'
  endif
  let l:instance.packager = a:packager
  let l:instance.name = !empty(l:instance.name) ? l:instance.name : split(a:name, '/')[-1]
  let l:instance.dir = printf('%s%s%s%s%s', a:packager.dir, s:slash, l:instance.type, s:slash, l:instance.name)
  let l:instance.local = get(l:instance, 'local', 0)
  let l:instance.rtp_dir = !empty(l:instance.rtp)
        \ ? printf('%s__%s', l:instance.dir, substitute(l:instance.rtp, '[\\\/]$', '', ''))
        \ : ''
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
  let l:instance.installed_now = 0
  let l:instance.status = ''
  let l:instance.status_msg = ''
  if isdirectory(l:instance.dir)
    let l:instance.installed = 1
    if s:is_windows
      call l:instance.revision('async')
      call l:instance.get_head_ref('async')
      call l:instance.get_main_branch('async')
    endif
  endif
  return l:instance
endfunction

function! s:plugin.queue() abort
  if !s:is_windows
    let self.rev = self.revision()
  endif

  let l:msg = self.installed ? 'Updating...' : 'Installing...'
  return self.set_status('progress', l:msg)
endfunction

function! s:plugin.set_status(status, status_msg) abort
  let self.status = a:status
  let self.status_msg = a:status_msg
endfunction

function! s:plugin.update_git_command() abort
  let l:update_cmd = ['cd']
  if s:is_windows
    let l:update_cmd += ['/d']
  endif
  let l:update_cmd += [self.dir]
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

  if !l:has_checkout && self.get_head_ref() ==? 'HEAD' && !empty(self.get_main_branch())
    let l:is_on_branch = v:true
    let l:update_cmd += ['&&', 'git', 'checkout', self.main_branch]
  endif

  if l:is_on_branch
    let l:update_cmd += ['&&', 'git', 'pull', '--ff-only', '--progress', '--rebase=false']
  else
    let l:update_cmd += ['&&', 'git', 'fetch', self.url]
  endif
  let l:update_cmd += ['&&', 'git', 'submodule', 'update', '--init', '--recursive', '--progress']

  return l:update_cmd
endfunction

function! s:plugin.install_git_command(depth) abort
  let l:depth = !empty(self.commit) ? '999999' : a:depth
  let l:clone_cmd = ['git', 'clone', '--progress', self.url, self.dir, '--depth', l:depth]

  if empty(self.commit)
    for l:branch_or_tag in [self.tag, self.branch]
      if !empty(l:branch_or_tag)
        let l:clone_cmd += ['--branch', l:branch_or_tag]
        break
      endif
    endfor
  endif

  let l:clone_cmd += ['&&', 'cd']
  if s:is_windows
    let l:clone_cmd += ['/d']
  endif
  let l:clone_cmd += [self.dir, '&&', 'git', 'submodule', 'update', '--init', '--recursive', '--progress']

  if !empty(self.commit)
    let l:clone_cmd += ['&&', 'git', 'checkout', self.commit]
  endif

  return l:clone_cmd
endfunction

function! s:plugin.local_command() abort
  let l:cmd = packager#utils#symlink(fnamemodify(self.url, ':p'), self.dir)

  if !empty(l:cmd)
    return l:cmd
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

function! s:plugin.get_last_update(...) abort
  let l:cmd = ['git', '-C', self.dir, 'log',
        \ '--color=never', '--pretty=format:"%h %s (%cr)"', '--no-show-signature', 'HEAD@{1}..'
        \ ]

  if a:0 > 0 && a:1 ==? 'async' && s:is_windows
    return packager#utils#system_async(l:cmd, self, 'last_update', {
          \ 'all': v:true,
          \ 'formatter': {val -> filter(val, 'v:val !=? "" && v:val !~? "^fatal"')}
          \ })
  endif

  let l:commits = packager#utils#system(l:cmd)
  let self.last_update = filter(l:commits, 'v:val !=? "" && v:val !~? "^fatal"')

  return self.last_update
endfunction

function! s:plugin.revision(...) abort
  let l:cmd = ['git', '-C', self.dir, 'rev-parse', 'HEAD']
  if a:0 > 0 && a:1 ==? 'async'
    return packager#utils#system_async(l:cmd, self, 'rev')
  endif

  let l:rev = get(packager#utils#system(l:cmd), 0, '')
  if l:rev =~? '^fatal'
    return ''
  endif
  return l:rev
endfunction

function! s:plugin.get_head_ref(...) abort
  if !empty(self.head_ref)
    return self.head_ref
  endif

  let l:cmd = ['git', '-C', self.dir, 'rev-parse', '--abbrev-ref', 'HEAD']

  if a:0 > 0 && a:1 ==? 'async'
    return packager#utils#system_async(l:cmd, self, 'head_ref')
  endif

  let l:head = get(packager#utils#system(l:cmd), 0, '')
  let self.head_ref = l:head =~? '^fatal' ? '' : l:head

  return self.head_ref
endfunction

function! s:plugin.get_main_branch(...) abort
  if !empty(self.main_branch)
    return self.main_branch
  endif

  let l:cmd = ['git', '-C', self.dir, 'symbolic-ref', 'refs/remotes/origin/HEAD']

  if a:0 > 0 && a:1 ==? 'async'
    return packager#utils#system_async(l:cmd, self, 'main_branch', {
        \ 'formatter': {val -> get(split(val, '/'), -1, '')} })
  endif

  let l:ref = get(packager#utils#system(l:cmd), 0, '')
  let self.main_branch = l:ref =~? '^fatal' ? '' : get(split(l:ref, '/'), -1, '')

  return self.main_branch
endfunction

function! s:plugin.symlink_rtp() abort
  if empty(self.rtp_dir)
    return 0
  endif

  let l:dir = printf('%s/%s', self.dir, self.rtp)
  let l:symlink_cmd = packager#utils#symlink(l:dir, self.rtp_dir)

  if !empty(l:symlink_cmd)
    return packager#utils#system(l:symlink_cmd)
  endif

  return 0
endfunction

function! s:plugin.update_install_status() abort
  if !self.installed
    let self.installed = 1
    let self.updated = 1
    let self.installed_now = 1
    call self.symlink_rtp()
    return 'Installed!'
  endif

  if self.has_updates()
    let self.updated = 1
    call self.get_last_update('async')
    call self.symlink_rtp()
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

  if self.installed_now
    return [packager#utils#status_ok(self.name, 'Installed!')]
  endif

  if !self.updated
    call self.get_last_update()
  endif

  if empty(self.last_update)
    return [packager#utils#status_ok(self.name, 'OK.')]
  endif

  let l:update_text = self.updated ? 'Updated!' : 'Last update:'
  let l:result = [packager#utils#status_ok(self.name, l:update_text)]
  for l:update in self.last_update
    call add(l:result, printf('  * %s', l:update))
  endfor
  return l:result
endfunction
