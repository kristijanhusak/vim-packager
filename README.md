# Vim packager

This is Yet Another plugin manager for Vim/Neovim. It utilizes [jobs](https://neovim.io/doc/user/job_control.html) and [pack](https://neovim.io/doc/user/repeat.html#packages) features, thus Vim 8+ is required.

Currently tested only on Neovim on Linux.

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


## Installation

#### Vim
```sh
git clone https://github.com/kristijanhusak/vim-packager ~/.vim/pack/packager/opt/vim-packager
```

#### Neovim
```sh
git clone https://github.com/kristijanhusak/vim-packager ~/.config/nvim/pack/packager/opt/vim-packager
```

#### Vimrc content

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
  call packager#add('Shougo/deoplete.nvim')
  call packager#add('autozimu/LanguageClient-neovim', { 'do': 'bash install.sh' })
  call packager#add('morhetz/gruvbox')
  "Git submodules example
  call packager#add('Valloric/YouCompleteMe', { 'do': 'git submodule update --init --recursive --progress && ./install.py'})
endfunction

command! PackagerInstall call PackagerInit() | call packager#install()
command! PackagerUpdate call PackagerInit() | call packager#update()
command! PackagerClean call PackagerInit() | call packager#clean()
command! PackagerStatus call PackagerInit() | call packager#status()
```

After that, reload vimrc, and run `:PackagerInstall`. It will install all the plugins and run it's hooks.

If some plugin installation (or it's hook) fail, you will get (as much as possible) descriptive error on the plugin line.


### Functions

#### packager#init(options)

Available options:

* `depth` - `--depth` value to use when cloning. Default: `5`
* `jobs` - Maximum number of jobs that can run at same time. `0` is treated as unlimited. Default: `8`
* `dir` - Directory to use for installation. By default uses `&packpath` value, which is `~/.vim/pack/packager` in Vim, and `~/.config/nvim/pack/packager` in Neovim.

#### packager#add(name, options)

`name` - Url to the git directory, or only last part of it to use `github`.

Example: for github repositories, `kristijanhusak/vim-packager` is enough, for something else, like `bitbucket`, use full path `https://bitbucket.org/owner/package`

Options:
* `name` - Custom name of the plugin. If ommited, last part of url explained above is taken (example: `vim-packager`, in `kristijanhusak/vim-packager`)
* `type` - In which folder to install the plugin. Plugins that are loaded on demand (with `packadd`), goes to `opt` directory,
where plugins that are auto loaded goes to `start` folder. Default: `start`
* `branch` - git branch to use. Default: '' (Uses the default from the repository, usually master)
* `tag` - git tag to use. Default: ''
* `commit` - exact git commit to use. Default: '' (Check below for priority explanation)
* `do` - Hook to run after plugin is installed/updated: Default: ''
* `frozen` - When plugin is frozen, it is not being updated. Default: 0

`branch`, `tag` and `commit` options go in certain priority:
* `commit`
* `tag`
* `branch`

## Thanks to:

* [@k-takata](https://github.com/k-takata) and his [minpac](https://github.com/k-takata/minpac) plugin for inspiration and parts of the code
