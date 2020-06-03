# Vim packager

![preview-gif](https://i.imgur.com/KOTn843.gif)

This is Yet Another plugin manager for Vim/Neovim. It's written in pure vimscript and utilizes [jobs](https://neovim.io/doc/user/job_control.html) and [pack](https://neovim.io/doc/user/repeat.html#packages) features.

Tested with:
* Neovim 0.3.2 - Linux, MacOS and Windows 10
* Vim 8.0 - Linux and Windows 10

## Why?
There's a lot of plugin managers for vim out there.

Most popular one is definitely [vim-plug](https://github.com/junegunn/vim-plug). It's a great fully featured plugin manager.
One thing that it does different is managing `runtimepath` manually. In latest Vim (and Neovim), packages can be added to `runtimepath` automatically by vim, just by placing the plugins in the right folder.
This also has one more advantage: You can use (load) plugin manager only when you need it.

One plugin manager that utilizes the same features as this one is [minpac](https://github.com/k-takata/minpac),
which I used for some time, and which inspired me to write this one (Many thanks to @k-takata).
In minpac, I missed having the window which shows the process and information about
all the plugins while they are being installed/updated/previewed.
I contributed and added a status window, but it still has a bit bad looking install/update process (echoing information to command line).
You can easily loose track what's happening in the process, and echoing causes a lot "Press enter to continue." messages, which blocks the process.

`Packager` utilizes jobs feature to the maximum, and runs everything that it can in a job, and shows whole process in the separate window, in a very similar way that vim-plug does.

## Requirement
* Neovim 0.20+ OR Vim 8.0.0902+
* Git
* Windows, Linux, macOS

## Installation
### Mac/Linux
#### Vim
```sh
git clone https://github.com/kristijanhusak/vim-packager ~/.vim/pack/packager/opt/vim-packager
```

#### Neovim
```sh
git clone https://github.com/kristijanhusak/vim-packager ~/.config/nvim/pack/packager/opt/vim-packager
```

### Windows
#### Vim
```sh
git clone https://github.com/kristijanhusak/vim-packager ~/vimfiles/pack/packager/opt/vim-packager
```

#### Neovim
```sh
git clone https://github.com/kristijanhusak/vim-packager ~/AppData/Local/nvim/pack/packager/opt/vim-packager
```

#### Example .vimrc content

```vimL
if &compatible
  set nocompatible
endif

" Load packager only when you need it
function! PackagerInit() abort
  packadd vim-packager
  call packager#init()
  call packager#add('kristijanhusak/vim-packager', { 'type': 'opt' })
  call packager#add('junegunn/fzf', { 'do': './install --all && ln -s $(pwd) ~/.fzf'})
  call packager#add('junegunn/fzf.vim')
  call packager#add('vimwiki/vimwiki', { 'type': 'opt' })
  call packager#add('Shougo/deoplete.nvim')
  call packager#add('autozimu/LanguageClient-neovim', { 'do': 'bash install.sh' })
  call packager#add('morhetz/gruvbox')
  call packager#local('~/my_vim_plugins/my_awesome_plugin')

  "Provide full URL; useful if you want to clone from somewhere else than Github.
  call packager#add('https://my.other.public.git/tpope/vim-fugitive.git')

  "Provide SSH-based URL; useful if you have write access to a repository and wish to push to it
  call packager#add('git@github.com:mygithubid/myrepo.git')

  "Loaded only for specific filetypes on demand. Requires autocommands below.
  call packager#add('kristijanhusak/vim-js-file-import', { 'do': 'npm install', 'type': 'opt' })
  call packager#add('fatih/vim-go', { 'do': ':GoInstallBinaries', 'type': 'opt' })
  call packager#add('neoclide/coc.nvim', { 'do': function('InstallCoc') })
  call packager#add('sonph/onehalf', {'rtp': 'vim/'})
endfunction

function! InstallCoc(plugin) abort
  exe '!cd '.a:plugin.dir.' && yarn install'
  call coc#add_extension('coc-eslint', 'coc-tsserver', 'coc-pyls')
endfunction

command! PackagerInstall call PackagerInit() | call packager#install()
command! -bang PackagerUpdate call PackagerInit() | call packager#update({ 'force_hooks': '<bang>' })
command! PackagerClean call PackagerInit() | call packager#clean()
command! PackagerStatus call PackagerInit() | call packager#status()

"Load plugins only for specific filetype
"Note that this should not be done for plugins that handle their loading using ftplugin file.
"More info in :help pack-add
augroup packager_filetype
  autocmd!
  autocmd FileType javascript packadd vim-js-file-import
  autocmd FileType go packadd vim-go
augroup END

"Lazy load plugins with a mapping
nnoremap <silent><Leader>ww :unmap <Leader>ww<BAR>packadd vimwiki<BAR>VimwikiIndex<CR>
```

After that, reload vimrc, and run `:PackagerInstall`. It will install all the plugins and run it's hooks.

If some plugin installation (or it's hook) fail, you will get (as much as possible) descriptive error on the plugin line.
To view more, press `E` on the plugin line to view whole stdout.


### Functions

#### packager#init(options)

Available options:

* `depth` - `--depth` value to use when cloning. Default: `5`
* `jobs` - Maximum number of jobs that can run at same time. `0` is treated as unlimited. Default: `8`
* `dir` - Directory to use for installation. By default uses `&packpath` value, which is `~/.vim/pack/packager` in Vim, and `~/.config/nvim/pack/packager` in Neovim.
* `window_cmd` - What command to use to open packager window. Default: `vertical topleft new`
* `default_plugin_type` - Default `type` option for plugins where it's not provided. More info below in `packager#add` options. Default: `start`
* `disable_default_mappings` - Disable all default mappings for packager buffer. Default: `0`

#### packager#add(name, options)

`name` - Url to the git directory, or only last part of it to use `github`.

Example: for github repositories, `kristijanhusak/vim-packager` is enough, for something else, like `bitbucket`, use full path `https://bitbucket.org/owner/package`

Options:
* `name` - Custom name of the plugin. If ommited, last part of url explained above is taken (example: `vim-packager`, in `kristijanhusak/vim-packager`)
* `type` - In which folder to install the plugin. Plugins that are loaded on demand (with `packadd`), goes to `opt` directory,
where plugins that are auto loaded goes to `start` folder. Default: `start`
* `branch` - git branch to use. Default: '' (Uses the default from the repository, usually master)
* `tag` - git tag to use. Default: ''
* `rtp` - Used in case when subdirectory contains vim plugin. Creates a symbolink link from subdirectory to the packager folder.
If `type` of package is `opt` use `packadd {packagename}__{rtp}` to load it (example: `packadd onehalf__vim`)
* `commit` - exact git commit to use. Default: '' (Check below for priority explanation)
* `do` - Hook to run after plugin is installed/updated: Default: ''
* `frozen` - When plugin is frozen, it is not being updated. Default: 0

`branch`, `tag` and `commit` options go in certain priority:
* `commit`
* `tag`
* `branch`

#### packager#local(name, options)
**Note**: This function only creates a symbolic link from provided path to the packager folder

`name` - Full path to the local folder
Example: `~/my_plugins/my_awesome_plugin`

Options:
* `name` - Custom name of the plugin. If ommited, last part of path is taken (example: `my_awesome_plugin`, in `~/my_plugins/my_awesome_plugin`)
* `type` - In which folder to install the plugin. Plugins that are loaded on demand (with `packadd`), goes to `opt` directory,
where plugins that are auto loaded goes to `start` folder. Default: `start`
* `do` - Hook to run after plugin is installed/updated: Default: ''
* `frozen` - When plugin is frozen, it is not being updated. Default: 0

#### packager#install(opts)

This only installs plugins that are not installed

Available options:

* `on_finish` - Run command after installation finishes. For example to quit at the end: `call packager#install({ 'on_finish': 'quitall' })`

When installation finishes, there are two mappings that can be used:

* `D` - Switches view from installation to status. This prints all plugins, and it's status (Installed, Updated, list of commits that were pulled with latest update)
* `E` - View stdout of the plugin on the current line. If something errored (From installation or post hook), it's printed in the preview window.

#### packager#update(opts)

This installs plugins that are not installed, and updates existing one to the latest (If it's not marked as frozen)

Available options:

* `on_finish` - Run command after update finishes. For example to quit at the end: `call packager#update({ 'on_finish': 'quitall' })`
* `force_hooks` - Force running post hooks for each package even if up to date. Useful when some hooks previously failed. Must be non-empty value: `call packager#update({ 'force_hooks': 1 })`

When update finishes, there are two mappings that can be used:

* `D` - Switches view from installation to status. This prints all plugins, and it's status (Installed, Updated, list of commits that were pulled with latest update)
* `E` - View stdout of the plugin on the current line. If something errored (From installation or post hook), it's printed in the preview window.

#### packager#status()

This shows the status for each plugin added from vimrc.

You can come to this view from Install/Update screens by pressing `D`.

Each plugin can have several states:

* `Not installed` - Plugin directory does not exist. If something failed during the clone process, shows the error message that can be previewed with `E`
* `Install/update failed` - Something went wrong during installation/updating of the plugin. Press `E` on the plugin line to view stdout of the process.
* `Post hook failed` - Something went wrong with post hook. Press `E` on the plugin line to view stdout of the process.
* `OK` - Plugin is properly installed and it doesn't have any update information.
* `Updated` - Plugin has some information about the last update.

#### packager#clean()

This removes unused plugins. It will ask for confirmation before proceeding.
Confirmation allows selecting option to delete all folders from the list (default action),
or ask for each folder if you want to delete it.

## Configuration
Several buffer mappings are added for packager buffer by default:

* `q` - Close packager buffer (`<Plug>(PackagerQuit)`)
* `<CR>` - Preview commit under cursor (`<Plug>(PackagerOpenSha)`)
* `E` - Preview stdout of the installation process of plugin under cursor (`<Plug>(PackagerOpenStdout)`)
* `<C-j>` - Jump to next plugin (`<Plug>(PackagerGotoNextPlugin)`)
* `<C-k>` - Jump to previous plugin (`<Plug>(PackagerGotoPrevPlugin)`)
* `D` - Go to status page (`<Plug>(PackagerStatus)`)
* `O` - Open details of plugin under cursor (`<Plug>(PackagerPluginDetails)`)

To use different mapping for any of these, create filetype autocmd with different mapping.

For example, to use `<c-h>` instead of `<c-j>` for jumping to next plugin, add this to vimrc:

```
autocmd FileType packager nmap <buffer> <C-h> <Plug>(PackagerGotoNextPlugin)
```

## Thanks to:

* [@k-takata](https://github.com/k-takata) and his [minpac](https://github.com/k-takata/minpac) plugin for inspiration and parts of the code
