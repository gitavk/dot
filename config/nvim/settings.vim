" Copy paste between vim and system clipboard
set clipboard=unnamedplus

" enable 256 colors
set t_Co=256
set t_ut=

" turn on line numbering
set number

" sane text files
set fileformat=unix
set encoding=utf-8
set fileencoding=utf-8

" sane editing
set tabstop=4
set softtabstop=4
set shiftwidth=4
set colorcolumn=100
set expandtab
set smartindent

" code folding
set foldmethod=indent
set foldlevel=99

" better view last line
set scrolloff=8

set noerrorbells                " No beeps
set novisualbell
set noswapfile                  " Don't use swapfile
set nobackup                    " Don't create annoying backup files
set splitright                  " Split vertical windows right to the current
set splitbelow                  " Split horizontal windows below to the

" execute code formater on save
autocmd BufWritePre *.py execute ':Black'
