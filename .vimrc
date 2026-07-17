set encoding=utf-8
set fileencodings=iso-2022-jp,euc-jp,sjis,utf-8
set fileformats=unix,dos,mac

""""""""""""""""""""""""""""""
" Plugin setup "
""""""""""""""""""""""""""""""
set runtimepath+=~/.vim/dein/repos/github.com/Shougo/dein.vim

if isdirectory(expand('~/.vim/dein/repos/github.com/Shougo/dein.vim'))
  call dein#begin(expand('~/.vim/dein'))

  call dein#add('Shougo/dein.vim')
  call dein#add('Shougo/vimproc.vim', {'build': 'make'})

  call dein#add('Shougo/unite.vim')
  call dein#add('Shougo/neomru.vim')
  call dein#add('w0rp/ale')
  call dein#add('vim-airline/vim-airline')
  call dein#add('Shougo/deoplete.nvim')
  call dein#add('sheerun/vim-polyglot')
  call dein#add('jiangmiao/auto-pairs')
  call dein#add('elzr/vim-json')
  call dein#add('tpope/vim-haml')
  call dein#add('vim-ruby/vim-ruby')
  call dein#add('othree/html5.vim')
  call dein#add('pangloss/vim-javascript')
  call dein#add('fatih/vim-go')
  call dein#add('SirVer/ultisnips')
  call dein#add('honza/vim-snippets')
  call dein#add('hashivim/vim-terraform')
  call dein#add('mattn/sonictemplate-vim')
  call dein#add('chr4/nginx.vim')

  call dein#end()

  if dein#check_install()
    call dein#install()
  end
endif

filetype plugin indent on
""""""""""""""""""""""""""""""

"Basic setting"
syntax on
colorscheme slate
set belloff=all
set number
set backspace=2 "make backspace work like most other programs"
set expandtab
set tabstop=2
set shiftwidth=2

let g:ale_lint_on_text_changed = 0
let g:airline#extensions#ale#open_lnum_symbol = '('
let g:airline#extensions#ale#close_lnumsymbol = ')'
let g:ale_echo_msg_format = '[%linter%]%code: %%s'
highlight link ALEErrorSign Tag
highlight link ALEWarningSign StorageClass

let g:terraform_fmt_on_save = 1
let g:sonictemplate_vim_template_dir = ['~/GitHub/configurations/vim/template']
