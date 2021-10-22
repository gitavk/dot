call plug#begin('~/.local/share/nvim/plugged')
    " color scheme
    Plug 'joshdick/onedark.vim'
    " langauge server (auto complete)
    Plug 'neovim/nvim-lspconfig'
    Plug 'hrsh7th/nvim-compe'
    " python code formater
    Plug 'psf/black', { 'branch': 'stable' }
    " git
    Plug 'tpope/vim-fugitive'
call plug#end()
