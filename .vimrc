execute pathogen#infect()

"colorscheme
set termguicolors
"set t_Co=256
let g:gruvbox_italic=1
let g:gruvbox_transparent_bg=1
autocmd vimenter * ++nested colorscheme gruvbox
"set bg=light
set bg=dark
highlight Comment cterm=italic gui=italic
colorscheme gruvbox
"highlight Normal guibg=NONE ctermbg=NONE
"colorscheme desert

syntax enable
set mouse=a
language en_US.utf8
"set textwidth=80

"general
set nocompatible
filetype plugin on
set noswapfile
"set autochdir

set expandtab
set tabstop=2 "number of visual spaces per TAB
set softtabstop=2 " number of spaces in tab when editing
set smartindent
set shiftwidth=2

set relativenumber "set numbers to lines
set nu "add absolute number to current line
set showcmd " show command in bottom bar
set wildmenu " visual autocomplete for command menu
set modeline
set ls=2 "show name
set incsearch           " search as characters are entered
set hidden "switch between buffer witout saving
set path+=** "search down into subfolders-provides tab-completion for all file related task

set foldmethod=syntax "folding
set foldlevel=99

set scrolloff=8
set signcolumn=yes
set guicursor+=n-v-c:blinkon0
set guicursor+=i:blinkwait10
"set noerrorbells
set noshowmode
set cmdheight=2
set shortmess+=c
set updatetime=50
set nohlsearch

"permettere di caricare .vimrc specifici di progetto in subfolders
set exrc
set secure




"find
nnoremap <F3> :execute "grep! -Irn --exclude=tags " . shellescape(expand("<cword>")) . " ."<cr>:cw<cr>
vnoremap <F3> y:vimgrep '<c-r>"' **/*.c **/*.cpp **/*.h<CR>:cw<cr>
"vmap :%s/parolaDaSost/Sostituta/gc


"whitespaces highlight (call before :set hlsearch)
"nnoremap <leader>sp /\s\+$
command! RemoveTrailingSpaces %s/\s\+$//g | noh

" bind § to grep shortcut
command! -nargs=+ -complete=file -bar Cerca execute 'silent! grep! -Ir <args> --exclude=tags --exclude=*.html --exclude=*.js' | execute 'redraw!' | execute 'cw'
nnoremap § :Cerca<SPACE>

"ripgrep
nnoremap <c-f> :Rg -tc -tcpp -ttxt<SPACE>
vnoremap <c-f> y:Rg -tc -tcpp -ttxt <C-r>*<CR>:cw<CR>

" bind  for breakpoints to clipboard for gdb
command! Xg :let @+ = 'b ' . expand('%:p') . ':' . line('.')
nnoremap °° :Xg<CR>

"ALT mapping for moving lines
nnoremap <C-j> ddp
nnoremap <C-k> ddkP

"in insert and visual mode ctrl-jk to move line up and down
inoremap <C-j> <Esc>:m .+1<CR>zR<CR>==gi
inoremap <C-k> <Esc>:m .-2<CR>zR<CR>==gi
vnoremap <C-j> :m '>+1<CR>zR<CR>gv=gv
vnoremap <C-k> :m '<-2<CR>zR<CR>gv=gv

"in normal mode ctrl-jklh to move between splits
"nnoremap <C-J> <C-W><C-J>
"nnoremap <C-K> <C-W><C-K>
"nnoremap <C-L> <C-W><C-L>
"nnoremap <C-H> <C-W><C-H>


"resize panes
"set nocompatible
noremap <C-Right> :vertical resize +5<CR>
noremap <C-Left> :vertical resize -5<CR>
noremap <C-Up> :resize +5<CR>
noremap <C-Down> :resize -5<CR>

"disabilitare freccie
"nnoremap <Left> :echo "No left for you!"<CR>
"vnoremap <Left> :<C-u>echo "No left for you!"<CR>
"inoremap <Left> <C-o>:echo "No left for you!"<CR>
"nnoremap <Right> :echo "No left for you!"<CR>
"vnoremap <Right> :<C-u>echo "No left for you!"<CR>
"inoremap <Right> <C-o>:echo "No left for you!"<CR>
"nnoremap <Up> :echo "No left for you!"<CR>
"vnoremap <Up> :<C-u>echo "No left for you!"<CR>
"inoremap <Up> <C-o>:echo "No left for you!"<CR>
"nnoremap <Down> :echo "No left for you!"<CR>
"vnoremap <Down> :<C-u>echo "No left for you!"<CR>
"inoremap <Down> <C-o>:echo "No left for you!"<CR>

"remap esc and :
nnoremap ò :
vnoremap ò :
nnoremap à /
vnoremap à /
inoremap jk <ESC>
let mapleader=" "
nnoremap <leader><leader> <c-^>
nnoremap <leader>. @:

nnoremap : ò
vnoremap : ò

nnoremap <leader>t :term<CR>
"tnoremap <Esc> <C-\><C-n>

nnoremap <leader>el :20Lex<CR>
nnoremap <leader>ee :Ex<CR>

"avoid paste to replace copy register
vnoremap p pgvy
"vnoremap <leader>p "_dP
"vnoremap p "_dP
noremap <leader>p "+p
nnoremap <leader>y "+yy
vnoremap <leader>y "+y
nnoremap <leader>Y gg"+yG












"######      PLUGIN      #######

call plug#begin('~/.vim/plugged')

Plug 'puremourning/vimspector'
Plug 'tpope/vim-fugitive'
Plug 'octol/vim-cpp-enhanced-highlight'
Plug 'cdelledonne/vim-cmake'
Plug 'jreybert/vimagit'
Plug 'tpope/vim-obsession'
Plug 'junegunn/fzf.vim'
Plug 'junegunn/fzf'
Plug 'liuchengxu/vista.vim'
Plug 'vimwiki/vimwiki'
Plug 'airblade/vim-gitgutter'
Plug 'preservim/nerdcommenter'

"Plug 'junegunn/gv.vim'
"Plug 'vim-utils/vim-man'
"Plug 'mbbill/undotree'
"Plug 'vuciv/vim-bujo'
"Plug 'tpope/vim-dispatch'
"Plug 'theprimeagen/vim-be-good'
"Plug '/home/theprimeagen/personal/af-pluth-pluth'
"Plug 'gruvbox-community/gruvbox'
"Plug 'tpope/vim-projectionist'

if has('nvim')
  "lsp Plugins
  Plug 'neovim/nvim-lspconfig'
  Plug 'nvim-lua/completion-nvim'
 " Plug 'nvim-lua/lsp-status.nvim'
 " Plug 'nvim-telescope/telescope.nvim'
 " Plug 'nvim-telescope/telescope-fzy-native.nvim'

  " Neovim Tree shitter
  Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
  Plug 'nvim-treesitter/playground'

else
  Plug 'ycm-core/YouCompleteMe'
endif

call plug#end()

"comments
let g:NERDCreateDefaultMappings = 1

"airline bar
let g:pymode_options_colorcolumn = 0
let g:airline#extensions#tabline#enabled = 1
let g:indentLine_enabled = 1
"let g:airline_theme='solarized_flood'
"let g:airline_powerline_fonts = 1
"let g:airline#extensions#wordcount#enabled = 0

"Termdebug
packadd termdebug
nnoremap <leader>dd :Termdebug<CR>
nnoremap <leader>dg :Gdb<CR>
nnoremap <leader>db :Break<CR>
nnoremap <leader>ds :Step<CR>
nnoremap <leader>dr :Run<CR>
nnoremap <leader>dl :Over<CR>
nnoremap <leader>dj :Step<CR>
nnoremap <leader>dk :Finish<CR>
nnoremap <leader>dc :Continue<CR>
"packadd! vimspector
nnoremap <leader>di :call vimspector#Launch()<CR>
nnoremap <leader>de :call vimspector#Reset()<CR>
nnoremap <leader>dp :call vimspector#ToggleBreakpoint()<CR>

"youCompleteMe
if !has('nvim')
  nnoremap <leader>gg <plug>(YCMHover)
  nnoremap <leader>lo :lopen<CR>
  nnoremap <silent>gt :YcmCompleter GoTo<CR>
  nnoremap <silent>gd :YcmCompleter GoToDeclaration<CR>
  nnoremap <silent>gi :YcmCompleter GoToDefinition<CR>
  nnoremap <silent>gr :YcmCompleter GoToReferences<CR>
  nnoremap <silent>gs :YcmCompleter GoToSymbol<CR>
  let g:ycm_auto_hover=''
  let g:ycm_global_ycm_extra_conf = '~/.vim/bundle/YouCompleteMe/.ycm_extra_conf.py'
  let g:ycm_enable_diagnostic_signs=1
  let g:ycm_always_populate_location_list = 1
endif
  set signcolumn=yes

"clangd-xtensa da usare con progetti esp:
"let g:ycm_clangd_binary_path = "/hdd1/repos/llvm-project/clang-tools-extra/clangd"
"highlight YcmErrorLine guibg=#f7d1b2
"nmap <> <ESC> :YcmCompleter Format<CR>
" Use <c-space> to trigger completion.
"inoremap <silent><expr> <c-space> coc#refresh()



"sessione \s
nnoremap <leader>sd :mksession!<CR>
nnoremap <leader>so :Obsession<CR>
nnoremap <leader>sr :source Session.vim<CR>
nnoremap <leader>ss :mksession ~/.saved_vim_sessions/
nnoremap <leader>sl :source ~/.saved_vim_sessions/

"git vim-fugitive \g
nnoremap <leader>gs :Gstatus<CR>
nnoremap <leader>gc :GBranches<CR>
nnoremap <leader>gl :Git gg<CR>
nnoremap <leader>gd :Git difftool<CR>
nnoremap <leader>gh :diffget //3<CR>
nnoremap <leader>gu :diffget //2<CR>

"fuzzy finder
"set rtp+=~/.fzf
nnoremap <silent> <c-p> :Files<CR>
nnoremap <silent> <leader>p :GitFiles<CR>
let $FZF_DEFAULT_OPT='--reverse'
let g:fzf_layout = { 'window': { 'width': 0.8, 'height': 0.8 } }


"cdelledonne/vim-cmake
let g:cmake_default_config = 'build'
"let g:cmake_generate_options = ['-GNinja', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON']
let g:cmake_generate_options = ['-GNinja', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON', '-DPYTHON_DEPS_CHECKED=1', '-DESP_PLATFORM=1', '-DIDF_TARGET=esp32', '-DCCACHE_ENABLE=0']
let g:cmake_root_markers = ['build']
let g:cmake_link_compile_commands = 1
nnoremap ,cc :CMakeGenerate<CR>
nnoremap ,ck :CMakeBuild<CR>
nnoremap ,cv :CMakeBuild -v<CR>
nnoremap ,cx :CMakeClean<CR>
nnoremap ,cz :!cd build && ninja clean<CR>
nnoremap ,ce :!cd build && ninja<CR>
nnoremap ,cf :!cd build && ESPPORT=/dev/ttyUSB0 ESPBAUD=2000000 ninja flash<CR>
nnoremap ,cm :!cd build && ESPPORT=/dev/ttyUSB0 ESPBAUD=2000000 ninja flash monitor<CR>
nnoremap ,ce :!cd build && ESPPORT=/dev/ttyUSB0 ninja erase_flash<CR>
nnoremap ,ca :!cmake -GNinja -B ../build && cmake --build ../build -v<CR>
nnoremap ,cb :make -C build<CR><CR>:cw<CR>
set makeprg=ninja
nnoremap ,cw :CMakeClean<CR>:CMakeGenerate<CR>:make -C build<CR><CR>:cw<CR>


"vim.cpp
let g:cpp_class_scope_highlight = 1
let g:cpp_member_variable_highlight = 1
let g:cpp_class_decl_highlight = 1
let g:cpp_posix_standard = 1
"let g:cpp_experimental_simple_template_highlight = 1
"let g:cpp_experimental_template_highlight = 1
"let g:cpp_concepts_highlight = 1
"let g:cpp_no_function_highlight = 1

""coc
"" if hidden is not set, TextEdit might fail.
"set hidden
"" Some servers have issues with backup files, see #649
"set nobackup
"set nowritebackup
"" Better display for messages
"set cmdheight=2
"" You will have bad experience for diagnostic messages when it's default 4000.
""set updatetime=300
"" don't give |ins-completion-menu| messages.
"set shortmess+=c
"" always show signcolumns
"set signcolumn=yes
"" Use tab for trigger completion with characters ahead and navigate.
"" Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
"inoremap <silent><expr> <TAB>
"      \ pumvisible() ? "\<C-n>" :
"      \ <SID>check_back_space() ? "\<TAB>" :
"      \ coc#refresh()
"inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
"function! s:check_back_space() abort
"  let col = col('.') - 1
"  return !col || getline('.')[col - 1]  =~# '\s'
"endfunction
"" Use <c-space> to trigger completion.
""inoremap <silent><expr> <c-space> coc#refresh()
"" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
"" Coc only does snippet and additional edit on confirm.
""inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
"" Use `[c` and `]c` to navigate diagnostics
""nmap <silent> [c <Plug>(coc-diagnostic-prev)
""nmap <silent> ]c <Plug>(coc-diagnostic-next)
"" Remap keys for gotos
""nmap <silent> gd <Plug>(coc-definition)
""nmap <silent> gy <Plug>(coc-type-definition)
""nmap <silent> gi <Plug>(coc-implementation)
""nmap <silent> gr <Plug>(coc-references)
"" Use K to show documentation in preview window
""nnoremap <silent> K :call <SID>show_documentation()<CR>
""function! s:show_documentation()
""  if (index(['vim','help'], &filetype) >= 0)
""    execute 'h '.expand('<cword>')
""  else
""    call CocAction('doHover')
""  endif
""endfunction
"" Highlight symbol under cursor on CursorHold
""autocmd CursorHold * silent call CocActionAsync('highlight')


"ctags stuff..
"example to include some libraries: map <F2> :!ctags -R --sort=yes --c++-kinds=+p --fields=+iaS --extra=+q . /usr/include/alsa/ /usr/include/Wt/<CR>
map <F2> :!ctags -R --sort=yes --c++-kinds=+p --fields=+iaS --extras=+q .<CR>
"map <F2> :!ctags -R --sort=yes --c++-kinds=+p --fields=+iaS --extras=+q . /home/steph/miniGW/framework/v3.1/<CR>
"map <F2> :!ctags -R * --fields=+S /usr/include<CR>
"map <F2> :!ctags -R *

"let project_make_path = 'build' "set here the makefile dir.current folder: getcwd()
"autocmd filetype c nnoremap <F7> :w <bar> exec '!cd '.shellescape(project_make_path).' && make'<CR><CR>:cw<CR>

"change here below the path of makefile with -> -C <path_where_makefile_is_loacted>
"default: map <F7> <ESC>:w<CR>:cexpr []<CR>:make<CR>:cw<CR>
"example: map <F7> <ESC>:w<CR>:cexpr []<CR>:make -C build<CR>:cw<CR>
"current qt project:
map <F7> <ESC>:w<CR>:cexpr []<CR>:make -C build<CR>:cw<CR>
"
"map <F7> <ESC>:w<CR>:!cd build && make<CR>:cw<CR>
"map <F7> <ESC>:w<CR>:!make<CR>:cw<CR>

" default: map <F8> <ESC>:w<CR>:make clean<CR><CR>:cw<CR>
map <F8> <ESC>:w<CR>:make clean -C build<CR><CR>:cw<CR>

"try to fast compile by type
autocmd filetype python nnoremap <F9> :w <bar> exec '!python<CR>
autocmd filetype c nnoremap <F9> :w <bar> exec '!gcc -g '.shellescape('%').' -o '.shellescape('%:r')<CR>
autocmd filetype cpp nnoremap <F9> :w <bar> exec '!g++ -g -std=c++11 '.shellescape('%').' -o '.shellescape('%:r')<CR>
autocmd filetype java nnoremap <F9> :w <bar> exec '!javac '.shellescape('%')<CR>
"try to fast compile and run
autocmd filetype python nnoremap <F5> :w <bar> exec '!python '.shellescape('%')<CR>
autocmd filetype c nnoremap <F5> :w <bar> exec '!gcc -g '.shellescape('%').' -o '.shellescape('%:r').' && ./'.shellescape('%:r')<CR>
autocmd filetype cpp nnoremap <F5> :w <bar> exec '!g++ -g -std=c++11 '.shellescape('%').' -o '.shellescape('%:r').' && ./'.shellescape('%:r')<CR>
autocmd filetype java nnoremap <F5> :w <bar> exec '!javac '.shellescape('%').' && java '.shellescape('%:r')<CR>
"java run work only with class of the same name of the file

map <C-F12> <C-w>g<C-]>
map <F12> <ESC>:w<CR> <C-]>

"jump to header in C++
nnoremap ,h :find %:t:r.h<CR>
nnoremap ,H :sp %:t:r.h<CR>
nnoremap ,s :find %:t:r.cpp<CR>
nnoremap ,S :sp %:t:r.cpp<CR>


"highlight tab and spaces
map <F4> :match Conceal /\t/
"set match Error /\S\zs\s\+$

" colorscheme e bg transparent
function! MyHighlights() abort
     hi Normal guibg=NONE ctermbg=NONE
endfunction

augroup MyColors
    autocmd!
    autocmd ColorScheme * call MyHighlights()
augroup END
colorscheme gruvbox
"hi Normal guibg=NONE ctermbg=NONE


"cycle throught items in cwindow and lwindow
nnoremap <C-k> :cp<CR>zz
nnoremap <C-j> :cn<CR>zz
nnoremap <leader>k :lnext<CR>zz
nnoremap <leader>j :lprev<CR>zz

"cycling between buffers
nnoremap <TAB> :bn<CR>
nnoremap <S-TAB> :bp<CR>

"vimdiff
nnoremap ç [c
nnoremap é ]c

"set curernt file to path
nnoremap <leader>cd :cd %:p:h<CR>

"to be tested
nnoremap <leader>ghw :h <C-R>=expand("<cword>")<CR><CR>
nnoremap <leader>bs /<C-R>=escape(expand("<cWORD>"), "/")<CR><CR>
nnoremap <leader><CR> :so ~/.vimrc<CR>


"xtensa-clang
let g:ycm_clangd_uses_ycmd_caching = 0
let g:ycm_clangd_binary_path = "clangd-xtensa"
let g:ycm_clangd_args = ['-log=verbose', '-pretty'] "-background-index
