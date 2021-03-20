execute pathogen#infect() 

colorscheme gruvbox 
"highlight Normal guibg=NONE ctermbg=NONE
let g:gruvbox_italic=1 
"set t_Co=256
set bg=light
"set bg=dark
highlight Comment cterm=italic gui=italic
"colorscheme desert 
"
syntax enable 
set mouse=a
language en_US.utf8
"set textwidth=80

"general
set nocompatible
filetype plugin on
set noswapfile
"set autochdir
"

"loader dei plugin a runtime
let g:pymode_options_colorcolumn = 0
"let g:airline_theme='solarized_flood'
"let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
"let g:airline#extensions#wordcount#enabled = 0
let g:indentLine_enabled = 1

set termguicolors
set scrolloff=8
set signcolumn=yes
set guicursor+=n-v-c:blinkon0
set guicursor+=i:blinkwait10
set noerrorbells
set noshowmode
set cmdheight=2
set shortmess+=c
set updatetime=50

let mapleader=" "

"avoid paste to replace copy register
xnoremap p pgvy
"vnoremap <leader>p "_dP
nnoremap <leader>y "+y
vnoremap <leader>y "+y
nnoremap <leader>Y gg"+yG

"fun! TrimWhitespace()
"	let l:save = winsaveview()
"	keeppatterns %s/\s\+$//e
"	call winrestview(l:save)
"endfun
"
"augroup STEVE
"	autocmd!
"	autocmd BufWritePre * :call TrimWhitespace()
"augroup END


"remap esc and : 
nnoremap ò :
vnoremap ò :
nnoremap à /
vnoremap à /
inoremap jk <ESC>
inoremap kj <ESC>


"coc
" if hidden is not set, TextEdit might fail.
set hidden
" Some servers have issues with backup files, see #649
set nobackup
set nowritebackup
" Better display for messages
set cmdheight=2
" You will have bad experience for diagnostic messages when it's default 4000.
"set updatetime=300
" don't give |ins-completion-menu| messages.
set shortmess+=c
" always show signcolumns
set signcolumn=yes
" Use tab for trigger completion with characters ahead and navigate.
" Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
"inoremap <silent><expr> <c-space> coc#refresh()
" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
" Coc only does snippet and additional edit on confirm.
"inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
" Use `[c` and `]c` to navigate diagnostics
"nmap <silent> [c <Plug>(coc-diagnostic-prev)
"nmap <silent> ]c <Plug>(coc-diagnostic-next)
" Remap keys for gotos
"nmap <silent> gd <Plug>(coc-definition)
"nmap <silent> gy <Plug>(coc-type-definition)
"nmap <silent> gi <Plug>(coc-implementation)
"nmap <silent> gr <Plug>(coc-references)
" Use K to show documentation in preview window
"nnoremap <silent> K :call <SID>show_documentation()<CR>
"function! s:show_documentation()
"  if (index(['vim','help'], &filetype) >= 0)
"    execute 'h '.expand('<cword>')
"  else
"    call CocAction('doHover')
"  endif
"endfunction
" Highlight symbol under cursor on CursorHold
"autocmd CursorHold * silent call CocActionAsync('highlight')

"youCompleteMe
nnoremap <silent>gt :YcmCompleter GoTo<CR>
nnoremap <silent>gd :YcmCompleter GoToDeclaration<CR>
nnoremap <silent>gi :YcmCompleter GoToDefinition<CR>
nnoremap <silent>gr :YcmCompleter GoToReferences<CR>
nnoremap <silent>gs :YcmCompleter GoToSymbol<CR>
"nmap <> <ESC> :YcmCompleter Format<CR>


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

"tab_spaces
set tabstop=4 "number of visual spaces per TAB
set softtabstop=4 " number of spaces in tab when editing
set smartindent
set shiftwidth=2

"UI config
set relativenumber "set numbers to lines
set nu "add absolute number to current line
set showcmd " show command in bottom bar
set wildmenu " visual autocomplete for command menu
set modeline
set ls=2 "show name

set incsearch           " search as characters are entered
set hlsearch            " highlight matches

"folding
set foldmethod=syntax
set foldlevel=99

"switch between buffer witout saving
set hidden

"path
set path+=** "search down into subfolders-provides tab-completion for all file related task


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

	"find
nmap <F3> :execute "grep! -Irn --exclude=tags " . shellescape(expand("<cword>")) . " ."<cr>:cw<cr>
vmap <F3> y:vimgrep '<c-r>"' **/*.c **/*.cpp **/*.h<CR>:cw<cr>
"vmap :%s/parolaDaSost/Sostituta/gc 

"ripristina sessione \s
nnoremap <leader>sd :mksession!<CR>
nnoremap <leader>so :Obsession<CR>
nnoremap <leader>sr :source Session.vim<CR>
nnoremap <leader>ss :mksession ~/.saved_vim_sessions/
nnoremap <leader>sl :source ~/.saved_vim_sessions/

"vim-fugitive \g
nnoremap <leader>gs :Gstatus<CR>
nnoremap <leader>gl :Git ggd<CR>


" bind § to grep shortcut
command! -nargs=+ -complete=file -bar Cerca execute 'silent! grep! -Ir <args> --exclude=tags' | execute 'redraw!' | execute 'cw'
nnoremap § :Cerca<SPACE>

"ripgrep
nnoremap <C-f> :Rg -tc 

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
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

"highlight tab and spaces
map <F4> :match Conceal /\t/
"set match Error /\S\zs\s\+$

"cycling between buffers
map <F6> :bn<CR>

"jump to header in C++
nmap ,h :find %:t:r.h<CR>
nmap ,H :sp %:t:r.h<CR>
nmap ,s :find %:t:r.cpp<CR>
nmap ,S :sp %:t:r.cpp<CR>

"insert line without go in insert mode
"nmap oo o<Esc>k 
"nmap OO O<Esc>

" Commenting blocks of code.
autocmd FileType c,cpp,java,scala let b:comment_leader = '// '
autocmd FileType sh,ruby,python   let b:comment_leader = '# '
autocmd FileType conf,fstab       let b:comment_leader = '# '
autocmd FileType tex              let b:comment_leader = '% '
autocmd FileType mail             let b:comment_leader = '> '
autocmd FileType vim              let b:comment_leader = '" '
noremap <silent> ,cc :<C-B>silent <C-E>s/^/<C-R>=escape(b:comment_leader,'\/')<CR>/<CR>:nohlsearch<CR>
noremap <silent> ,cu :<C-B>silent <C-E>s/^\V<C-R>=escape(b:comment_leader,'\/')<CR>//e<CR>:nohlsearch<CR>

"cycle throught items in cwindows
map ç :cn<CR>
map é :cp<CR>

"resize panes
"set nocompatible
map <C-Right> :vertical resize +5<CR>
map <C-Left> :vertical resize -5<CR>
map <C-Up> :resize -5<CR>
map <C-Down> :resize +5<CR>


set exrc
set secure

"fuzzy finder
set rtp+=~/.fzf
nnoremap <silent> <C-p> :FZF<CR>
let $FZF_DEFAULT_OPT='--reverse'
"let g:fzf_layout = { 'window': { 'width': 0.8, 'height': 0.8 } }
