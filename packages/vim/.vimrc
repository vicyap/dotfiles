" Basic settings
set nocompatible
set encoding=utf-8
set fileencoding=utf-8

" Display
set number
set relativenumber
set ruler
set showcmd
set showmode
set cursorline
set laststatus=2

" Indentation
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

" Search
set hlsearch
set incsearch
set ignorecase
set smartcase

" Behavior
set backspace=indent,eol,start
set hidden
set autoread
set clipboard=unnamedplus

" Splits
set splitbelow
set splitright

" No swap/backup
set noswapfile
set nobackup
set nowritebackup

" Key mappings
let mapleader = " "
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Clear search highlight
nnoremap <leader><space> :nohlsearch<CR>

" Syntax
syntax enable
filetype plugin indent on
