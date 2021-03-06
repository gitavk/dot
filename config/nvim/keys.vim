" set leader key
let g:mapleader = "\<Space>"

" Alternate way to save
nnoremap <C-s> :w<CR>
" Alternate way to quit
nnoremap <C-q> :wq!<CR>

" Use alt + hjkl to resize windows
nnoremap <C-j> :resize -2<CR>
nnoremap <C-k> :resize +2<CR>
nnoremap <C-h> :vertical resize -2<CR>
nnoremap <C-l> :vertical resize +2<CR>

" Better tabbing
vnoremap < <gv
vnoremap > >gv

" windows navigation for multi mode
if has('mac')
    tnoremap ˙ <C-\><C-N><C-w>h
    inoremap ˙ <C-\><C-N><C-w>h
    nnoremap ˙ <C-w>h
    tnoremap ∆ <C-\><C-N><C-w>j
    inoremap ∆ <C-\><C-N><C-w>j
    nnoremap ∆ <C-w>j
    tnoremap ˚ <C-\><C-N><C-w>k
    inoremap ˚ <C-\><C-N><C-w>k
    nnoremap ˚ <C-w>k
    tnoremap ¬ <C-\><C-N><C-w>l
    inoremap ¬ <C-\><C-N><C-w>l
    nnoremap ¬ <C-w>l
else
    tnoremap <M-h> <C-\><C-N><C-w>h
    tnoremap <M-j> <C-\><C-N><C-w>j
    tnoremap <M-k> <C-\><C-N><C-w>k
    tnoremap <M-l> <C-\><C-N><C-w>l
    inoremap <M-h> <C-\><C-N><C-w>h
    inoremap <M-j> <C-\><C-N><C-w>j
    inoremap <M-k> <C-\><C-N><C-w>k
    inoremap <M-l> <C-\><C-N><C-w>l
    nnoremap <M-h> <C-w>h
    nnoremap <M-j> <C-w>j
    nnoremap <M-k> <C-w>k
    nnoremap <M-l> <C-w>l
endif


" git actions
nnoremap <leader>gb :Git blame<CR>
nnoremap <leader>gs :G<CR>
nmap <leader>gr :Gvdiffsplit!<CR>
nmap <leader>gl :diffget //3<CR>
nmap <leader>gh :diffget //2<CR>
