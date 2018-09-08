let s:vim_packager = {}

function! s:system(cmds) abort
  let l:out = []
  let l:job = vim_packager#job#start(a:cmds,
        \ {'on_stdout': {id, mes, ev -> extend(l:out, mes)}})
  if l:job > 0
    let l:ret = vim_packager#job#wait([l:job])[0]
    sleep 5m
  endif
  return [l:ret, l:out]
endfunction

function! vim_packager#init() abort
  let s:instance = s:vim_packager.New()
endfunction

function! vim_packager#quit() abort
  return s:instance.quit()
endfunction

function! vim_packager#add(name, ...) abort
  if !exists('s:instance')
    throw 'Call vim_packager#init() first.'
  endif
  return s:instance.Add(a:name, a:000)
endfunction

function! vim_packager#install() abort
  if !exists('s:instance')
    throw 'Call vim_packager#init() first.'
  endif

  return s:instance.Install()
endfunction

function! s:vim_packager.New() abort
  let l:instance = copy(self)
"  let l:instance.dir = printf('%s/%s', split(&packpath, ',')[0],
"  'pack/vim_packager')
  let l:instance.dir = printf('%s/%s', '/home/kristijan/github/test', 'pack/vim_packager')
  let l:instance.plugins = []
  silent! call mkdir(printf('%s/%s', l:instance.dir, 'opt'), 'p')
  silent! call mkdir(printf('%s/%s', l:instance.dir, 'start'), 'p')
  return l:instance
endfunction

function! s:vim_packager.Add(name, opts) abort
  let l:defaults = { 'dir': '', 'url': '', 'name': '', 'type': 'start', 'branch': '', 'installed': 0, 'updated': 0, 'rev': '', 'do': '' }
  let l:plugin = extend(copy(get(a:opts, 0, {})), l:defaults, 'keep')
  let l:plugin.name = !empty(l:plugin.name) ? l:plugin.name : split(a:name, '/')[-1]
  let l:plugin.dir = !empty(l:plugin.dir) ? fnamemodify(l:plugin.dir, ':p') : printf('%s/%s/%s', self.dir, l:plugin.type, l:plugin.name)
  let l:plugin.url = a:name =~? '^http.*' ? a:name : printf('https://github.com/%s', a:name)
  if isdirectory(l:plugin.dir)
    let l:plugin.installed = 1
    let l:plugin.rev = self.plugin_revision(l:plugin)
  endif
  call add(self.plugins, l:plugin)
endfunction

function! s:vim_packager.plugin_revision(plugin) abort
  return get(s:system(printf('git -C %s rev-parse HEAD', a:plugin.dir)), 0, '')
endfunction

function! s:vim_packager.update_top_status() abort
  let l:total = len(self.plugins)
  let l:installed = l:total - self.remaining_jobs
  call setline(1, printf('Installed plugins %d of %d', l:installed, l:total))
  return setline(2, '')
endfunction

function! s:hook_stdout_handler(plugin, id, message, event) dict
  if a:event !=? 'exit'
    let l:msg = get(split(a:message[0], '\r'), -1, a:message[0])
    return setline(a:plugin.line, printf('✓ %s - %s', a:plugin.name, l:msg))
  endif

  let self.remaining_jobs -= 1
  if a:message !=? 0
    return setline(a:plugin.line, printf('✗ %s - %s', a:plugin.name, 'Error on hook - status '.a:message))
  endif

  return setline(a:plugin.line, printf('✓ %s - %s', a:plugin.name, 'Finished running post update hook!'))
endfunction

function! s:stdout_handler(plugin, id, message, event) dict
  let l:existing_line = search('^\(+\|✗\|✓\)\s'.a:plugin.name, 'n')
  let l:line = !l:existing_line ? 2 : l:existing_line
  let l:append_fn = l:existing_line ? 'setline' : 'append'
  let a:plugin.line = l:line

  if a:event !=? 'exit'
    let l:msg = get(split(a:message[0], '\r'), -1, a:message[0])
    return call(l:append_fn, [l:line, printf('+ %s - %s', a:plugin.name, l:msg)])
  endif

  if a:message !=? 0
    let self.remaining_jobs -= 1
    return call(l:append_fn, [l:line, printf('✗ %s - %s', a:plugin.name, 'Error - status code '.a:message)])
  endif

  if !a:plugin.installed
    let l:text = 'Installed!'
    let a:plugin.installed = 1
    let a:plugin.updated = 1
  else
    let l:rev = self.plugin_revision(a:plugin)
    if !empty(l:rev) && l:rev !=? a:plugin.rev
      let l:text = 'Updated!'
      let a:plugin.updated = 1
    else
      let l:text = 'Already up to date.'
    endif
  endif

  call call(l:append_fn, [l:line, printf('✓ %s - %s', a:plugin.name, l:text)])
  call self.update_top_status()

  if a:plugin.updated && !empty(a:plugin.do)
    call call(l:append_fn, [l:line, printf('✓ %s - %s', a:plugin.name, 'Running post update hooks...')])
    let l:hook_job = vim_packager#job#start(a:plugin.do, {
          \ 'cwd': a:plugin.dir,
          \ 'on_stdout': function('s:hook_stdout_handler', [a:plugin], self),
          \ 'on_stderr': function('s:hook_stdout_handler', [a:plugin], self),
          \ 'on_exit': function('s:hook_stdout_handler', [a:plugin], self),
          \ })
  else
    let self.remaining_jobs -= 1
  endif

  if self.remaining_jobs <=? 0
    call self.post_update_hooks()
  endif
endfunction

function! s:vim_packager.post_update_hooks() abort
  "TODO
endfunction

function! s:vim_packager.open_buffer() abort
  vertical topleft new
  setf vim_packager
  setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap cursorline nospell
  syntax clear
  syn match vimPackagerCheck /^✓/
  syn match vimPackagerPlus /^+/
  syn match vimPackagerX /^✗/
  syn match vimPackagerStatus /\(^+.*-\)\@<=\s.*$/
  syn match vimPackagerStatusSuccess /\(^✓.*-\)\@<=\s.*$/
  syn match vimPackagerStatusError /\(^✗.*-\)\@<=\s.*$/

  hi def link vimPackagerPlus           Special
  hi def link vimPackagerCheck          Function
  hi def link vimPackagerX              WarningMsg
  hi def link vimPackagerStatus         Constant
  hi def link vimPackagerStatusSuccess  Function
  hi def link vimPackagerStatusError    WarningMsg
  nnoremap <silent><buffer> q :call vim_packager#quit()<CR>
endfunction

function! s:vim_packager.quit()
  if self.remaining_jobs > 0
    let l:decision = confirm('Installation is in progress. Are you sure you want to quit?', "&Yes\n&No")
    if l:decision != 1
      return
    endif
  endif
  silent exe ':q!'
endfunction

function! s:vim_packager.Install() abort
  let self.result = []
  let self.remaining_jobs = len(self.plugins)
  call self.open_buffer()
  call self.update_top_status()
  for l:plugin in self.plugins
    if isdirectory(l:plugin.dir)
      let l:cmd = ['git', '-C', l:plugin.dir, 'pull', '--ff-only', '--progress']
    else
      let l:cmd = ['git', 'clone', '--progress', l:plugin.url, l:plugin.dir]
    endif
      let l:job = vim_packager#job#start(l:cmd, {
            \ 'on_stdout': function('s:stdout_handler', [l:plugin], self),
            \ 'on_stderr': function('s:stdout_handler', [l:plugin], self),
            \ 'on_exit': function('s:stdout_handler', [l:plugin], self),
            \ })
  endfor
endfunction
