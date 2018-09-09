let s:packager = {}
let s:defaults = {
      \ 'dir': printf('%s/%s', split(&packpath, ',')[0], 'pack/packager'),
      \ 'depth': 5
      \ }

function! packager#new(opts) abort
  return s:packager.new(a:opts)
endfunction

function! s:packager.new(opts) abort
  let l:instance = extend(copy(self), extend(copy(a:opts), s:defaults, 'keep'))
  if has_key(a:opts, 'dir')
    let l:instance.dir = substitute(fnamemodify(a:opts.dir, ':p'), '\/$', '', '')
    echom l:instance.dir
  endif
  let l:instance.plugins = []
  silent! call mkdir(printf('%s/%s', l:instance.dir, 'opt'), 'p')
  silent! call mkdir(printf('%s/%s', l:instance.dir, 'start'), 'p')
  return l:instance
endfunction

function! s:packager.add(name, opts) abort
  let l:plugin = packager#plugin#new(a:name, a:opts, self.dir)
  if len(filter(copy(self.plugins), printf('v:val.name ==? "%s"', l:plugin.name))) > 0
    return
  endif
  return add(self.plugins, l:plugin)
endfunction

function! s:packager.update_top_status() abort
  let l:total = len(self.plugins)
  let l:installed = l:total - self.remaining_jobs
  call setline(1, printf('Installed plugins %d / %d', l:installed, l:total))
  return setline(2, '')
endfunction

function! s:packager.update_top_status_installed() abort
  let self.remaining_jobs -= 1
  if self.remaining_jobs < 0
    let self.remaining_jobs = 0
  endif
  return self.update_top_status()
endfunction

function! s:packager.post_update_hooks() abort
  "TODO
endfunction

function! s:packager.open_buffer() abort
  vertical topleft new
  setf packager
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
  nnoremap <silent><buffer> q :call packager#quit()<CR>
endfunction

function! s:packager.quit()
  if self.remaining_jobs > 0
    let l:decision = confirm('Installation is in progress. Are you sure you want to quit?', "&Yes\n&No")
    if l:decision != 1
      return
    endif
  endif
  silent exe ':q!'
endfunction

function! s:packager.install() abort
  let self.result = []
  let self.remaining_jobs = len(self.plugins)
  call self.open_buffer()
  call self.update_top_status()
  for l:plugin in self.plugins
    call packager#job#start(l:plugin.git_command(self.depth), {
          \ 'on_stdout': function('s:stdout_handler', [l:plugin], self),
          \ 'on_stderr': function('s:stdout_handler', [l:plugin], self),
          \ 'on_exit': function('s:stdout_handler', [l:plugin], self),
          \ })
  endfor
endfunction

function! s:hook_stdout_handler(plugin, id, message, event) dict
  if a:event !=? 'exit'
    let l:msg = get(split(a:message[0], '\r'), -1, a:message[0])
    return a:plugin.update_status('ok', l:msg)
  endif

  call self.update_top_status_installed()
  "TODO: Add better message
  if a:message !=? 0
    return a:plugin.update_status('error', printf('Error on hook - status %s', a:message))
  endif

  return a:plugin.update_status('ok', 'Finished running post update hook!')
endfunction

function! s:stdout_handler(plugin, id, message, event) dict
  echom a:message[0]
  if a:event !=? 'exit'
    let l:msg = get(split(a:message[0], '\r'), -1, a:message[0])
    return a:plugin.update_status('progress', l:msg)
  endif

  if a:message !=? 0
    call self.update_top_status_installed()
    return a:plugin.update_status('error', printf('Error - status code %d', a:message))
  endif

  call a:plugin.update_install_status()

  if a:plugin.updated && !empty(a:plugin.do)
    call a:plugin.update_status('ok', 'Running post update hooks...')
    if a:plugin.do[0] ==? ':'
      try
        exe a:plugin.do[1:]
        call a:plugin.update_status('ok', 'Finished running post update hook!')
      catch
        call a:plugin.update_status('error', printf('Error on hook - %s', v:exception))
      endtry
      call self.update_top_status_installed()
    else
      let l:hook_job = packager#job#start(a:plugin.do, {
            \ 'cwd': a:plugin.dir,
            \ 'on_stdout': function('s:hook_stdout_handler', [a:plugin], self),
            \ 'on_stderr': function('s:hook_stdout_handler', [a:plugin], self),
            \ 'on_exit': function('s:hook_stdout_handler', [a:plugin], self),
            \ })
    endif
  else
    call self.update_top_status_installed()
  endif

  if self.remaining_jobs <=? 0
    call self.post_update_hooks()
  endif
endfunction
