set nocompatible              " be iMproved, required
filetype off                  " required

" vim-plug to manage plugin
call plug#begin('~/.vim/plugged')
" browse file
Plug 'preservim/nerdtree', { 'on': 'NERDTreeToggle' }
" browse code
Plug 'preservim/tagbar'
" color theme, choose 1 in 2
Plug 'morhetz/gruvbox'
Plug 'joshdick/onedark.vim'
" multi-language support
Plug 'sheerun/vim-polyglot'
" cscope data base load and key maps
Plug 'dr-kino/cscope-maps'
" status bar
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
" git intergration
Plug 'tpope/vim-fugitive'
call plug#end()

"nerdtree
nnoremap <C-\>n :NERDTreeToggle<CR>

"tagbar
nnoremap <C-\>b :TagbarToggle<CR>
let g:tagbar_autopreview=1
let g:tagbar_show_data_type = 1
let g:tagbar_show_tag_linenumbers = 2
let g:tagbar_sort=0

"pathogen for self-managed plugin
execute pathogen#infect()

"linux code style
" 100 characters line
"set colorcolumn=100
"execute "set colorcolumn=" . join(range(101,101), ',')
"highlight ColorColumn ctermbg=blue ctermfg=DarkRed
" Highlight trailing spaces
" http://vim.wikia.com/wiki/Highlight_unwanted_spaces
" highlight ExtraWhitespace ctermbg=red guibg=red
" match ExtraWhitespace /\s\+$/
" autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
" autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
" autocmd InsertLeave * match ExtraWhitespace /\s\+$/
" autocmd BufWinLeave * call clearmatches()

" airline config
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#tab_nr_type = 1 " tab number
let g:airline#extensions#tabline#show_tab_nr = 1
let g:airline#extensions#tabline#formatter = 'default'
let g:airline#extensions#tabline#buffer_nr_show = 0
let g:airline#extensions#tabline#fnametruncate = 16
let g:airline#extensions#tabline#fnamecollapse = 2
let g:airline#extensions#tabline#buffer_idx_mode = 1
" uncomment when enable gruvbox
let g:airline_theme = 'gruvbox'
" uncomment when enable onedark
" let g:airline_theme = 'onedark'

" vim theme
" config 24bit color 
set termguicolors

" gruvbox theme config
colorscheme gruvbox
set background=dark    " Setting dark mode
" set background=light   " Setting light mode
" let g:gruvbox_number_column = "gray"

" one dark config
" syntax enable
" set background=dark
" colorscheme onedark


" vim config
set wildmenu
set number
set ruler
set showcmd
set ai
set showmatch
set showmode
set hlsearch

"set expandtab
set tabstop=4
set shiftwidth=4

set backspace=indent,eol,start

nnoremap <F4> :set hlsearch! hlsearch?<CR>
" switch between different vim buffer
" tab to switch to next buffer
noremap <TAB> :bnext<CR>
" shift+tab to switch to previous buffer
nnoremap <S-Tab> :bprev<CR>

" Uncomment the following to have Vim jump to the last position when
" reopening a file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
    \| exe "normal! g'\"" | endif
endif

