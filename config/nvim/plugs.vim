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
    " status line
    Plug 'nvim-lualine/lualine.nvim'
    " If you want to have icons in your statusline choose one of these
    Plug 'kyazdani42/nvim-web-devicons'
call plug#end()
