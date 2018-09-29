let s:packager = {}
let s:slash = exists('+shellslash') && !&shellslash ? '\' : '/'
let s:defaults = {
      \ 'dir': printf('%s%s%s', split(&packpath, ',')[0], s:slash, 'pack'.s:slash.'packager'),
      \ 'depth': 5,
      \ 'jobs': 8,
      \ }

function! packager#new(opts) abort
  return s:packager.new(a:opts)
endfunction

function! s:packager.new(opts) abort
  call packager#utils#check_support()
  let l:instance = extend(copy(self), extend(copy(a:opts), s:defaults, 'keep'))
  if has_key(a:opts, 'dir')
    let l:instance.dir = substitute(fnamemodify(a:opts.dir, ':p'), '\'.s:slash.'$', '', '')
  endif
  let l:instance.plugins = {}
  let l:instance.processed_plugins = {}
  let l:instance.remaining_jobs = 0
  let l:instance.running_jobs = 0
  silent! call mkdir(printf('%s%s%s', l:instance.dir, s:slash, 'opt'), 'p')
  silent! call mkdir(printf('%s%s%s', l:instance.dir, s:slash, 'start'), 'p')
  return l:instance
endfunction

function! s:packager.add(name, opts) abort
  let l:plugin = packager#plugin#new(a:name, a:opts, self)
  let self.plugins[l:plugin.name] = l:plugin
endfunction

function! s:packager.install(opts) abort
  let self.result = []
  let self.processed_plugins = filter(copy(self.plugins), 'v:val.installed ==? 0')
  let self.remaining_jobs = len(self.processed_plugins)

  if self.remaining_jobs ==? 0
    echo 'Nothing to install.'
    return
  endif

  let self.post_run_opts = a:opts
  call self.open_buffer()
  call self.update_top_status()
  for l:plugin in values(self.processed_plugins)
    call self.start_job(l:plugin.git_command(self.depth), {
          \ 'handler': 's:stdout_handler',
          \ 'plugin': l:plugin,
          \ 'limit_jobs': v:true
          \ })
  endfor
endfunction

function! s:packager.update(opts) abort
  let self.result = []
  let self.processed_plugins = filter(copy(self.plugins), 'v:val.frozen ==? 0')
  let self.remaining_jobs = len(self.processed_plugins)

  if self.remaining_jobs ==? 0
    echo 'Nothing to update.'
    return
  endif

  let self.post_run_opts = a:opts
  let self.command_type = 'update'
  call self.open_buffer()
  call self.update_top_status()
  for l:plugin in values(self.processed_plugins)
    call self.start_job(l:plugin.git_command(self.depth), {
          \ 'handler': 's:stdout_handler',
          \ 'plugin': l:plugin,
          \ 'limit_jobs': v:true
          \ })
  endfor
endfunction

function! s:packager.clean() abort
  let l:folders = glob(printf('%s%s*%s*', self.dir, s:slash, s:slash), 0, 1)
  let self.processed_plugins = copy(self.plugins)
  let l:plugins = values(map(copy(self.processed_plugins), 'substitute(v:val.dir, ''\(\\\|\/\)'', s:slash, ''g'')'))
  function! s:clean_filter(plugins, key, val)
    return index(a:plugins, a:val) < 0
  endfunction

  let l:to_clean = filter(copy(l:folders), function('s:clean_filter', [l:plugins]))

  if len(l:to_clean) <=? 0
    echo 'Already clean.'
    return 0
  endif

  call self.open_buffer()
  call setline(1, 'Clean up.')
  call setline(2, '')

  for l:item in l:to_clean
    call append(2, packager#utils#status_progress(l:item, 'Waiting for confirmation...'))
  endfor

  if !packager#utils#confirm('Remove above folder(s)?')
    return self.quit()
  endif

  for l:item in l:to_clean
    let l:line = search(printf('^+\s%s\s—', escape(l:item, '/\')), 'n')
    if delete(l:item, 'rf') !=? 0
      call setline(l:line, packager#utils#status_error(l:item, 'Failed.'))
    else
      call setline(l:line, packager#utils#status_ok(l:item, 'Removed!'))
    endif
  endfor
endfunction

function! s:packager.status() abort
  if self.is_running()
    echo 'Install/Update process still in progress. Please wait until it finishes to view the status.'
    return
  endif
  let l:result = []
  let self.processed_plugins = copy(self.plugins)
  let l:has_errors = 0

  for l:plugin in values(self.processed_plugins)
    let l:plugin_status = l:plugin.get_content_for_status()

    for l:status_line in l:plugin_status
      call add(l:result, l:status_line)
    endfor

    if !l:plugin.installed || l:plugin.update_failed || l:plugin.hook_failed
      let l:has_errors = 1
    endif
  endfor

  call self.open_buffer()
  call setline(1, 'Plugin status.')
  call setline(2, '')
  call append(2, l:result)

  call append('$', '')
  call append('$', "Press 'Enter' on commit lines to preview the commit.")
  if l:has_errors
    call append('$', "Press 'E' on errored plugins to view stdout.")
  endif
  call append('$', "Press 'q' to quit this buffer.")
  setlocal nomodifiable
endfunction

function! s:packager.quit()
  if self.is_running()
    if !packager#utils#confirm('Installation is in progress. Are you sure you want to quit?')
      return
    endif
  endif
  silent exe ':q!'
endfunction

function! s:packager.update_top_status() abort
  let l:total = len(self.processed_plugins)
  let l:installed = l:total - self.remaining_jobs
  let l:finished = self.remaining_jobs > 0 ? '' : ' - Finished!'
  call setline(1, printf('Installed plugins %d / %d%s', l:installed, l:total, l:finished))
  return setline(2, '')
endfunction

function! s:packager.update_top_status_installed() abort
  let self.remaining_jobs -= 1
  let self.remaining_jobs = max([0, self.remaining_jobs]) "Make sure it's not negative
  let self.running_jobs -= 1
  let self.running_jobs = max([0, self.running_jobs]) "Make sure it's not negative
  return self.update_top_status()
endfunction

function! s:packager.run_post_update_hooks() abort
  if has_key(self, 'post_run_hooks_called')
    return
  endif

  let self.post_run_hooks_called = 1

  if getbufvar(bufname('%'), '&filetype') ==? 'packager'
    call append('$', '')
    call append('$', "Press 'D' to view latest updates.")
    call append('$', "Press 'E' on a plugin line to see stdout in preview window.")
    call append('$', "Press 'q' to quit this buffer.")
    setlocal nomodifiable
  endif

  call self.update_remote_plugins_and_helptags()

  if has_key(self, 'post_run_opts') && has_key(self.post_run_opts, 'on_finish')
    silent! exe 'redraw'
    exe self.post_run_opts.on_finish
  endif
endfunction

function! s:packager.open_buffer() abort
  let l:is_current_packager = &filetype ==? 'packager'

  if !l:is_current_packager
    let l:packager_window_numbers = filter(range(1, winnr('$')), 'getwinvar(v:val, "&filetype") ==? "packager"')
    if len(l:packager_window_numbers) > 0
      silent! exe printf('%dwincmd w', l:packager_window_numbers[0])
      let l:is_current_packager = 1
    endif
  endif

  if l:is_current_packager
    set modifiable
    silent! exe 'norm!gg"_dG'
  else
    vertical topleft new
  endif

  setf packager
  setlocal modifiable buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap cursorline nospell
  syntax clear
  syn match packagerCheck /^✓/
  syn match packagerPlus /^+/
  syn match packagerX /^✗/
  syn match packagerStar /^\s\s\*/
  syn match packagerStatus /\(^+.*—\)\@<=\s.*$/
  syn match packagerStatusSuccess /\(^✓.*—\)\@<=\s.*$/
  syn match packagerStatusError /\(^✗.*—\)\@<=\s.*$/
  syn match packagerStatusCommit /\(^\*.*—\)\@<=\s.*$/
  syn match packagerSha /\(\*\s\)\@<=[0-9a-f]\{4,}/
  syn match packagerRelDate /([^)]*)$/

  hi def link packagerPlus           Special
  hi def link packagerCheck          Function
  hi def link packagerX              WarningMsg
  hi def link packagerStar           Boolean
  hi def link packagerStatus         Constant
  hi def link packagerStatusCommit   Constant
  hi def link packagerStatusSuccess  Function
  hi def link packagerStatusError    WarningMsg
  hi def link packagerSha            Identifier
  hi def link packagerRelDate        Comment
  nnoremap <silent><buffer> q :call g:packager.quit()<CR>
  nnoremap <silent><buffer> <CR> :call g:packager.open_sha()<CR>
  nnoremap <silent><buffer> E :call g:packager.open_stdout()<CR>
  nnoremap <silent><buffer> <C-j> :call g:packager.goto_plugin('next')<CR>
  nnoremap <silent><buffer> <C-k> :call g:packager.goto_plugin('previous')<CR>
  nnoremap <silent><buffer> D :call g:packager.status()<CR>
endfunction

function! s:packager.open_sha() abort
  let l:sha = matchstr(getline('.'), '^\s\s\*\s\zs[0-9a-f]\{7,9}')
  if empty(l:sha)
    return
  endif

  let l:plugin = self.find_plugin_by_sha(l:sha)

  if empty(l:plugin)
    return
  endif

  silent exe 'pedit' l:sha
  wincmd p
  setlocal previewwindow filetype=git buftype=nofile nobuflisted modifiable
  let l:sha_content = packager#utils#system(['git', '-C', l:plugin.dir, 'show',
        \ '--no-color', '--pretty=medium', l:sha
        \ ])

  call append(0, l:sha_content)
  setlocal nomodifiable
  nnoremap <silent><buffer> q :q<CR>
endfunction

function! s:packager.open_stdout(...) abort
  let l:is_hook = a:0 > 0
  let l:plugin_name = packager#utils#trim(matchstr(getline('.'), '^.\s\zs[^—]*\ze'))
  if !has_key(self.plugins, l:plugin_name)
    return
  endif

  let l:content = self.plugins[l:plugin_name].get_stdout_messages()
  if empty(l:content)
    echo 'No stdout content to show.'
    return
  endif

  silent exe 'pedit' l:plugin_name
  wincmd p
  setlocal previewwindow filetype=sh buftype=nofile nobuflisted modifiable
  silent! exe 'norm!gg"_dG'
  call append(0, l:content)
  setlocal nomodifiable
  nnoremap <silent><buffer> q :q<CR>
endfunction

function! s:packager.find_plugin_by_sha(sha) abort
  for l:plugin in values(self.processed_plugins)
    let l:commits = filter(copy(l:plugin.last_update), printf("v:val =~? '^%s'", a:sha))
    if len(l:commits) > 0
      return l:plugin
    endif
  endfor

  return {}
endfunction

function! s:packager.goto_plugin(dir) abort
  let l:icons = join(values(packager#utils#status_icons()), '\|')
  let l:flag = a:dir ==? 'previous' ? 'b': ''
  return search(printf('^\(%s\)\s.*$', l:icons), l:flag)
endfunction

function! s:packager.update_remote_plugins_and_helptags() abort
  for l:plugin in values(self.processed_plugins)
    if l:plugin.updated
      silent! exe 'helptags' fnameescape(printf('%s%sdoc', l:plugin.dir, s:slash))

      if has('nvim') && isdirectory(printf('%s%srplugin', l:plugin.dir, s:slash))
        call packager#utils#add_rtp(l:plugin.dir)
        exe 'UpdateRemotePlugins'
      endif
    endif
  endfor
endfunction

function! s:packager.start_job(cmd, opts) abort
  if has_key(a:opts, 'limit_jobs') && self.jobs > 0
    if self.running_jobs > self.jobs
      while self.running_jobs > self.jobs
        silent exe 'redraw'
        sleep 100m
      endwhile
    endif
    let self.running_jobs += 1
  endif

  let l:opts = {
        \ 'on_stdout': function(a:opts.handler, [a:opts.plugin], self),
        \ 'on_stderr': function(a:opts.handler, [a:opts.plugin], self),
        \ 'on_exit': function(a:opts.handler, [a:opts.plugin], self)
        \ }

  if has_key(a:opts, 'cwd')
    let l:opts.cwd = a:opts.cwd
  endif

  return packager#job#start(a:cmd, l:opts)
endfunction

function! s:packager.is_running() abort
  return self.remaining_jobs > 0
endfunction

function! s:stdout_handler(plugin, id, message, event) dict
  call a:plugin.log_event_messages(a:event, a:message)

  if a:event !=? 'exit'
    return a:plugin.update_status('progress', a:plugin.get_last_progress_message())
  endif

  if a:message !=? 0
    call self.update_top_status_installed()
    let a:plugin.update_failed = 1
    let l:err_msg = a:plugin.get_short_error_message()
    let l:err_msg = !empty(l:err_msg) ? printf(' - %s', l:err_msg) : ''
    return a:plugin.update_status('error', printf('Error (exit status %d)%s', a:message, l:err_msg))
  endif

  let l:status_text = a:plugin.update_install_status()

  if a:plugin.updated && !empty(a:plugin.do)
    call a:plugin.update_status('progress', 'Running post update hooks...')
    if a:plugin.do[0] ==? ':'
      try
        exe a:plugin.do[1:]
        call a:plugin.update_status('ok', 'Finished running post update hook!')
      catch
        call a:plugin.update_status('error', printf('Error on hook - %s', v:exception))
      endtry
      call self.update_top_status_installed()
    else
      call self.start_job(a:plugin.do, {
            \ 'handler': 's:hook_stdout_handler',
            \ 'plugin': a:plugin,
            \ 'cwd': a:plugin.dir
            \ })
    endif
  else
    call a:plugin.update_status('ok', l:status_text)
    call self.update_top_status_installed()
  endif

  if self.remaining_jobs <=? 0
    call self.run_post_update_hooks()
  endif
endfunction

function! s:hook_stdout_handler(plugin, id, message, event) dict
  call a:plugin.log_event_messages(a:event, a:message, 'hook')

  if a:event !=? 'exit'
    return a:plugin.update_status('progress', a:plugin.get_last_progress_message('hook'))
  endif

  call self.update_top_status_installed()
  if a:message !=? 0
    let l:err_msg = a:plugin.get_short_error_message('hook')
    let l:err_msg = !empty(l:err_msg) ? printf(' - %s', l:err_msg) : ''
    let a:plugin.hook_failed = 1
    call a:plugin.update_status('error', printf('Error on hook (exit status %d)%s', a:message, l:err_msg))
  else
    call a:plugin.update_status('ok', 'Finished running post update hook!')
  endif

  if self.remaining_jobs <=? 0
    call self.run_post_update_hooks()
  endif
endfunction
