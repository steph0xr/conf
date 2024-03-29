  "colorscheme
  set termguicolors
  "set t_Co=256
  let g:gruvbox_italic=1
  let g:gruvbox_bold=0
  let g:gruvbox_transparent_bg=1
  let g:gruvbox_contrast_dark = 'hard'
  let g:gruvbox_invert_selection='0'
  " autocmd vimenter * ++nested colorscheme gruvbox
  "set bg=light
  set bg=dark
  highlight Comment cterm=italic gui=italic

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

  " set foldmethod=syntax "folding
  " autocmd FileType c setlocal foldmethod=syntax
  " set foldlevel=99
  " nnoremap ,f :setlocal foldmethod=syntax<CR>zM

  " treesitter folding
  set foldmethod=expr
  set foldexpr=nvim_treesitter#foldexpr()
  set nofoldenable                     " Disable folding at startup.
  nnoremap ,ff :setlocal foldmethod=expr<CR>zM
  nnoremap ,f :setlocal foldmethod=syntax<CR>zM

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

  " bind ° to grep shortcut
  " command! -nargs=+ -complete=file -bar CercaNoStack execute 'silent! grep! -Ir <args> --exclude=tags --exclude=*.{html,js,json} --exclude-dir={customized-bin,stack_zigbee,build,gecko_sdk_suite_v3.1.2,gecko_sdk_suite_v3.0.2}' | execute 'redraw!' | execute 'cw'
  " nnoremap ° :CercaNoStack<SPACE>


  "find
  " nnoremap <F3> :execute "grep! -Irn --exclude=tags " . shellescape(expand("<cword>")) . " ."<cr>:cw<cr>
  " vnoremap <F3> y:vimgrep '<c-r>"' **/*.c **/*.cpp **/*.h<CR>:cw<cr>
  "vmap :%s/parolaDaSost/Sostituta/gc


  "whitespaces highlight (call before :set hlsearch)
  "nnoremap <leader>sp /\s\+$
  command! RemoveTrailingSpaces %s/\s\+$//g | noh

  " bind § to grep shortcut
  command! -nargs=+ -complete=file -bar Cerca execute 'silent! grep! -IrE <args> --exclude=tags --exclude=*.html --exclude=*.js' | execute 'redraw!' | execute 'cw'
  " nnoremap § :Cerca<SPACE>

  " command! -nargs=+ -complete=file -bar Cerca execute 'silent! vimgrep! <args>' | execute 'redraw!' | execute 'cw'

  " command -nargs=* Vgrep vimgrep /\v<args>/g **/* | copen
  command -nargs=* VgrepInGit vimgrep /\v<args>/g `git ls-files` | copen
  " nnoremap § :VgrepInGit<SPACE>


  " bind  for breakpoints to clipboard for gdb
  command! Xg :let @+ = 'b ' . expand('%:p') . ':' . line('.')
  nnoremap \\ :Xg<CR>

  command! Diff :windo diffthis
  nnoremap ,d :Diff<CR>
  nnoremap ,dl :diffget //2<CR>
  nnoremap ,dr :diffget //3<CR>


  "ALT mapping for moving lines
  "nnoremap <C-j> ddp
  "nnoremap <C-k> ddkP

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
  nnoremap - /
  nnoremap à /
  vnoremap - /
  nnoremap ) }
  nnoremap ( {
  inoremap jk <ESC>
  inoremap kj <ESC>
  inoremap jj <ESC>
  " inoremap <c-c> <ESC>
  let mapleader=" "
  nnoremap <leader><leader> <c-^>
  nnoremap <leader>. @:

  nnoremap : ò
  vnoremap : ò
  " nnoremap / -
  " vnoremap / -

  nnoremap <leader>t :term<CR>
  tnoremap <c-q> <C-\><C-n>
  tnoremap <ESC> <C-\><C-n>

  nnoremap <leader>el :20Lex<CR>
  nnoremap <leader>ee :Ex<CR>

  nnoremap <leader>ev :vsplit ~/.vimrc<cr>
  nnoremap <leader>ei :vsplit ~/.config/nvim/init.vim<cr>
  nnoremap <leader>eg :vsplit ~/.gitconfig<cr>

  "avoid paste to replace copy register
  vnoremap p pgvy
  "vnoremap <leader>p "_dP
  "vnoremap p "_dP
  noremap <leader>p "+p
  nnoremap <leader>y "+yy
  vnoremap <leader>y "+y
  nnoremap <leader>Y gg"+yG

  " nnoremap <leader>i ggVG=











  "######      PLUGIN      #######
  let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

  call plug#begin('~/.vim/plugged')

  Plug 'gruvbox-community/gruvbox'
  Plug 'sainnhe/gruvbox-material'
  " Plug 'puremourning/vimspector'
  Plug 'tpope/vim-fugitive'
  Plug 'rbong/vim-flog'
  Plug 'jreybert/vimagit'
  Plug 'tpope/vim-dispatch'
  " Plug 'octol/vim-cpp-enhanced-highlight'
  Plug 'bfrg/vim-cpp-modern'
  Plug 'cdelledonne/vim-cmake'
  Plug 'tpope/vim-obsession'
  Plug 'junegunn/fzf'
  Plug 'junegunn/fzf.vim'
  Plug 'wookayin/fzf-ripgrep.vim'
  Plug 'liuchengxu/vista.vim'
  Plug 'vimwiki/vimwiki'
  Plug 'airblade/vim-gitgutter'
  Plug 'preservim/nerdcommenter'
  Plug 'rhysd/vim-clang-format'
  Plug 'ThePrimeagen/vim-be-good'
   " Plug 'nvim-telescope/telescope-fzy-native.nvim'

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
    Plug 'hrsh7th/nvim-cmp'
    Plug 'hrsh7th/cmp-nvim-lsp'
    Plug 'hrsh7th/cmp-buffer'
    Plug 'hrsh7th/cmp-path'
    Plug 'hrsh7th/cmp-cmdline'
    " Plug 'L3MON4D3/LuaSnip'
    " Plug 'hrsh7th/vim-vsnip'
    " Plug 'hrsh7th/cmp-vsnip'
    Plug 'onsails/lspkind-nvim'
    " Plug 'nvim-lua/lsp-status.nvim'
    Plug 'nvim-lua/popup.nvim'
    Plug 'nvim-lua/plenary.nvim'
    Plug 'nvim-telescope/telescope.nvim'

    " Neovim Tree shitter
    Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
    Plug 'nvim-treesitter/playground'
    Plug 'nvim-treesitter/nvim-treesitter-textobjects'

    Plug 'ThePrimeagen/harpoon'
    Plug 'mfussenegger/nvim-dap'
    Plug 'rcarriga/nvim-dap-ui'
    Plug 'mfussenegger/nvim-dap-python'
    Plug 'szw/vim-maximizer'
    Plug 'mbbill/undotree'
    Plug 'rose-pine/neovim'

    Plug 'aklt/plantuml-syntax'
    Plug 'scrooloose/vim-slumlord'
    " Plug 'skanehira/preview-uml.vim'

  " else
    " Plug 'ycm-core/YouCompleteMe'
  endif

  call plug#end()





  "telescope
" nnoremap <leader>f :lua require('telescope.builtin').find_files(previewer = false})<cr>
nnoremap <leader>f :lua require('telescope.builtin').find_files({file_ignore_patterns = {'%.js','%.html'},previewer = false})<cr>
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>
nnoremap <leader>f. <cmd>Telescope search_dotfiles<cr>
nnoremap <leader>fg <cmd>Telescope git_files<cr>
nnoremap <leader>fc <cmd>Telescope git_commits<cr>
nnoremap <leader>ft <cmd>Telescope git_status<cr>
nnoremap <leader>fr <cmd>Telescope git_branches<cr>
nnoremap <leader>fl <cmd>Telescope live_grep<cr>
" nnoremap <leader>fx <cmd>Telescope oldfiles<cr>
nnoremap <leader>fx <cmd>Telescope diagnostics<cr>
nnoremap <leader>fa :lua require('telescope.builtin').grep_string({ search = vim.fn.input("Grep For > ")})<CR>
nnoremap <leader>fs :lua require('telescope.builtin').grep_string({ file_ignore_patterns = {'%.js','%.html'}, search = vim.fn.input("Grep For > ")})<CR>
" nnoremap <leader>fv :lua require('telescope.builtin').grep_string({ file_ignore_patterns = {'%.js','%.html'}, search_dirs={"%:p"}, word_match = "-w", search = vim.fn.input("Grep For > "), previewer = false})<CR>
vnoremap <leader>fv :lua require('telescope.builtin').grep_string({search_dirs={"%:p"}, search = vim.fn.expand("<cword>"), previewer = true })<CR>
nnoremap <leader>fo :lua require("telescope.builtin").live_grep({search_dirs={vim.fn.expand("%:p")}})<CR>
" nnoremap <leader>fo :lua require('telescope.builtin').grep_string({ file_ignore_patterns = {'%.js','%.html'}, word_match = "-w", search = vim.fn.input("Grep For > ")})<CR>
" nnoremap <leader>fo :lua require'telescope.builtin'.live_grep{ file_ignore_patterns = {'%.js','%.html'}, search_dirs={"%:p"} }
nnoremap <leader>fw :lua require('telescope.builtin').grep_string { file_ignore_patterns = {'%.js','%.html'}, search = vim.fn.expand("<cword>") }<CR>
nnoremap <leader>fe :lua require('telescope.builtin').grep_string { file_ignore_patterns = {'%.js','%.html'}, search = vim.fn.expand("<cword>"), previewer = false }<CR>
" nnoremap <leader>ps :lua require('telescope.builtin').grep_string({ search = vim.fn.input("Grep For > ")})<CR>
" nnoremap <C-p> :lua require('telescope.builtin').git_files()<CR>
" nnoremap <Leader>pf :lua require('telescope.builtin').find_files()<CR>
" nnoremap <leader>vh :lua require('telescope.builtin').help_tags()<CR>
" nnoremap <leader>gw :lua require('telescope').extensions.git_worktree.git_worktrees()<CR>
" nnoremap <leader>gm :lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>


"comments
let g:NERDCreateDefaultMappings = 1
let g:NERDSpaceDelims = 1 " Add spaces after comment delimiters by default
let g:NERDCompactSexyComs = 1 " Use compact syntax for prettified multi-line comments
let g:NERDTrimTrailingWhitespace = 1 " Enable trimming of trailing whitespace when uncommenting

"airline bar
let g:pymode_options_colorcolumn = 0
let g:airline#extensions#tabline#enabled = 1
let g:indentLine_enabled = 1
"let g:airline_theme='solarized_flood'
"let g:airline_powerline_fonts = 1
"let g:airline#extensions#wordcount#enabled = 0

" statusline
set statusline=
set statusline=%<%f%h%m%r%= 
set statusline+=%{FugitiveStatusline()}\ \|
set statusline+=\%b\ 0x%B\|\ %l,%c%V\ \ %P
" set statusline = "%%-4.4(%d%%)%%-15.23(%s%%)|%%-14.14(%s%%)%%-20.20(%s%%)%%-6.6(%s%%)%%-30.70(%s%%)"
" set statusline=%<%f%h%m%r%=%b\ 0x%B\ \ %l,%c%V\ %P


"Termdebug
packadd termdebug
" let g:termdebug_popup = 0
" let g:termdebug_wide = 163
let g:termdebug_wide = 0 
nnoremap ùd :Termdebug<CR>
" nnoremap <leader>dg :Gdb<CR>
nnoremap ùb :Break<CR>
nnoremap ùc :Continue<CR>
nnoremap ùe :Evaluate<CR>
nnoremap ùf :Finish<CR>
nnoremap ùh :Stop<CR>
nnoremap ùm :call TermDebugSendCommand('source .breakpoints')<CR>
nnoremap ùo :call TermDebugSendCommand('save br .breakpoints')<CR>
nnoremap ùy :call TermDebugSendCommand('info breakpoints')<CR>
nnoremap ùu :call TermDebugSendCommand('delete breakpoints')<CR>
nnoremap ùn :Over<CR>
nnoremap ùx :Clear<CR>
nnoremap ùs :Step<CR>
nnoremap ùr :Run<CR>
nnoremap ùs :Step<CR>
nnoremap ùq :call TermDebugSendCommand('q')<CR>:Gdb<CR>:q<CR>:call TermDebugSendCommand('save br .breakpoints')<CR>
nnoremap ùv :call TermDebugSendCommand('signal SIGINT')<CR>
"termina sessione remota gdbServer:
" nnoremap ,de :call TermDebugSendCommand('mon exit')<CR>
"packadd! vimspector
" nnoremap <leader>di :call vimspector#Launch()<CR>
" nnoremap <leader>de :call vimspector#Reset()<CR>
" nnoremap <leader>dp :call vimspector#ToggleBreakpoint()<CR>

" "youCompleteMe
" if !has('nvim')
  " nnoremap <leader>gg <plug>(YCMHover)
  " nnoremap <leader>lo :lopen<CR>
  " nnoremap <silent>gt :YcmCompleter GoTo<CR>
  " nnoremap <silent>gd :YcmCompleter GoToDeclaration<CR>
  " nnoremap <silent>gi :YcmCompleter GoToDefinition<CR>
  " nnoremap <silent>gr :YcmCompleter GoToReferences<CR>
  " nnoremap <silent>gs :YcmCompleter GoToSymbol<CR>
  " let g:ycm_auto_hover=''
  " let g:ycm_global_ycm_extra_conf = '~/.vim/bundle/YouCompleteMe/.ycm_extra_conf.py'
  " let g:ycm_enable_diagnostic_signs=1
  " let g:ycm_always_populate_location_list = 1
  " "xtensa-clang
  " let g:ycm_clangd_uses_ycmd_caching = 0
  " let g:ycm_clangd_binary_path = "clangd-xtensa"
  " let g:ycm_clangd_args = ['-log=verbose', '-pretty'] "-background-index
" endif
  " set signcolumn=yes

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
let g:fugitive_summary_format = "%<(18,trunc)%an|| %<(75,trunc)%s|| %<(55,trunc)%d||%<(12,trunc)%ar - %aI"
nnoremap <leader>g :Git status -s<CR>
nnoremap gs :Git<CR>
noremap gl :Gclog<CR>
nnoremap <leader>gc :GBranches<CR>
nnoremap <leader>gg :Flogsplit -all -date=relative -raw-args=--author-date-order -max-count=2000<CR>
nnoremap <leader>gd :Git difftool<CR>
nnoremap <leader>gs :Git<CR>
nnoremap <leader>gl :Gclog<CR>
"git follow a single file log history:
noremap  <leader>gf :Gclog -- %<CR> 
nnoremap <leader>gk :G log --graph --abbrev-commit --decorate=no --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(dim white)%s%C(reset) %C(bold blue)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all --tags <CR>
" let g:flog_default_arguments = {'max_count': 2000, 'all': 1, 'date': 'relative'}
" let g:flog_default_arguments = {'max_count': 2000, 'all': 1, 'format': '%C(bold blue)%>|(26)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(dim white)%s%C(reset) %C(bold blue)- %an%C(reset)%C(bold yellow)%d%C(reset)'}
" 'raw-args': '--tags',

"fuzzy finder
" nnoremap <silent> <c-p> :GitFiles<CR>
" nnoremap <silent> <leader>f :Files<CR>
let $FZF_DEFAULT_OPT='--reverse'
let g:fzf_layout = { 'window': { 'width': 0.8, 'height': 0.8 } }

"harpoon
nnoremap <leader>hh :lua require("harpoon.mark").add_file()<CR>
nnoremap <leader>hf :lua require("harpoon.ui").toggle_quick_menu()<CR>
nnoremap <leader>1 :lua require("harpoon.ui").nav_file(1)<CR>
nnoremap <leader>2 :lua require("harpoon.ui").nav_file(2)<CR>
nnoremap <leader>3 :lua require("harpoon.ui").nav_file(3)<CR>
nnoremap <leader>4 :lua require("harpoon.ui").nav_file(4)<CR>
nnoremap <leader>5 :lua require("harpoon.ui").nav_file(5)<CR>
nnoremap <leader>6 :lua require("harpoon.ui").nav_file(6)<CR>


"cdelledonne/vim-cmake
let g:cmake_default_config = 'build'
" let g:cmake_root_markers = ['.git', 'build']
let g:cmake_root_markers = ['build', '.git']
let g:cmake_generate_options = ['-GNinja', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON']
" let g:cmake_link_compile_commands = 1
" let g:cmake_jump = 1
" let g:cmake_jump_on_error = 0
nnoremap ,cb :CMakeBuild<CR>
nnoremap ,cx :CMakeClean<CR>
nnoremap ,cz :CMakeClose<CR>
nnoremap ,c :CMakeGenerate!<CR>
" Make dispatch to tmux
nnoremap ,m :Make -C build<CR><CR>:cw<CR>
nnoremap ,M :make! -C build<CR><CR>:cw<CR>
set makeprg=ninja
nnoremap ,R :Dispatch build/main/main<CR>
" nnoremap ,e :w<CR>:Make -C build<CR><CR>:cw<CR> \| :Start build/main/main<CR><CR>:cw<CR>
"nnoremap ,cw :CMakeClean<CR>:CMakeGenerate<CR>:make! -C build<CR><CR>:cw<CR>

" compilation: remove jump to warnings  
set errorformat^=%-G%f:%l:\ warning:%m

"vim.cpp
" let g:cpp_class_scope_highlight = 1
" let g:cpp_member_variable_highlight = 1
" let g:cpp_class_decl_highlight = 1
" let g:cpp_posix_standard = 1
"let g:cpp_experimental_simple_template_highlight = 1
"let g:cpp_experimental_template_highlight = 1
"let g:cpp_concepts_highlight = 1
"let g:cpp_no_function_highlight = 1
"
" let g:cpp_no_function_highlight = 1
" " Enable highlighting of C++11 attributes
let g:cpp_attributes_highlight = 1
" " Highlight struct/class member variables (affects both C and C++ files)
let g:cpp_member_highlight = 1
" " Put all standard C and C++ keywords under Vim's highlight group 'Statement'
" " (affects both C and C++ files)
" let g:cpp_simple_highlight = 1

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
nnoremap ,s :ClangdSwitchSourceHeader<CR>
" nnoremap ,h :find %:t:r.h<CR>
" nnoremap ,H :sp %:t:r.h<CR>
" nnoremap ,s :find %:t:r.cpp<CR>
" nnoremap ,S :sp %:t:r.cpp<CR>


"highlight tab and spaces
map <F4> :match Conceal /\t/
"set match Error /\S\zs\s\+$

" colorscheme e bg transparent
" function! MyHighlights() abort
     " hi Normal guibg=NONE ctermbg=NONE
" endfunction

" augroup MyColors
    " autocmd!
    " autocmd ColorScheme * call MyHighlights()
" augroup END
" colorscheme gruvbox
" colorscheme rose-pine


"cycle throught items in cwindow and lwindow
nnoremap <expr> <C-k> &diff? '[c' : ':cp<CR>zz'
nnoremap <expr> <C-j> &diff? ']c' : ':cn<CR>zz'
" nnoremap <leader>k :lnext<CR>zz
" nnoremap <leader>j :lprev<CR>zz

"cycling between buffers
" nnoremap <TAB> :bn<CR>
" nnoremap <S-TAB> :bp<CR>

"reload all buffers
" nnoremap <leader>r :bufdo e<CR>
nnoremap <leader>r :checktime<CR>

"vimdiff
if &diff
  hi DiffAdd    guifg=#003300 guibg=#DDFFDD
  hi DiffDelete    guifg=#003300 guibg=#FF0000
  hi DiffChange guifg=#003300 guibg=#DDDDFF
  hi DiffText   guifg=#006600 guibg=#DDDDFF
  syntax off
  nnoremap <C-k> [c
  nnoremap <C-j> ]c
  nnoremap <leader>g :diffget<CR>
  nnoremap <leader>p :diffput<CR>
  nnoremap <leader>r :diffget RE<CR>
  nnoremap <leader>l :diffget LO<CR>
  nnoremap <leader>b :diffget BA<CR>
  nnoremap <leader>< /<<<<<<<<CR>
  nnoremap <C-q> :cquit<CR>
endif

"set curernt file to path
nnoremap <leader>cd :cd %:p:h<CR>



"ripgrep
" nnoremap <c-f> :RgFzf *<CR>
"nnoremap <c-f> :Rg -tc -tcpp -ttxt *<CR>
" nnoremap <c-f> y:Rg <C-r>"<CR>:cw<CR>
"nnoremap <c-f> y:Rg -tc -tcpp -ttxt <C-r>"<CR>:cw<CR>
"
"to be tested
" nnoremap <leader>ghw :h <C-R>=expand("<cword>")<CR><CR>
" nnoremap <leader>bs /<C-R>=escape(expand("<cWORD>"), "/")<CR><CR>

nnoremap <leader><CR> :so $MYVIMRC<CR>
nnoremap <leader>i :so ~/.config/nvim/init.vim<CR>
" nnoremap <leader><CR> :so ~/.vimrc<CR>

"formatting
let g:clang_format#detect_style_file = 1
let g:clang_format#enable_fallback_style = 0
" nnoremap ,f :ClangFormat<CR>

"cpp copy class method definition for pasting in class declaration 
nnoremap ,h ==wwd2wA;<ESC>:w<CR>
" nnoremap <leader>hh pwd2wA;<ESC>I  <ESC>

"cmake output filtering
nnoremap <leader>x <c-w>jG:%s/error//gn<cr>
nnoremap ,x <c-w>j<c-w>jG/error<cr>:%s/error//gn<cr>

"no ex mode
noremap Q <Nop>

"keep found in center of screen
nnoremap n nzzzv
nnoremap N Nzzzv

autocmd FileType cpp set keywordprg=cppman


nnoremap ,pp :Dispatch python %<CR> 
nnoremap ,pd :term python %<CR> 

" map ,f :call getline(search("^[^ \t#/]\\{2}.*[^:]\s*$", 'bW')) <CR> %%b

let g:netrw_keepdir=0

nnoremap <leader>u :UndotreeToggle<CR>

" remove // when line before is commented
" set formatoptions-=cro
autocmd BufNewFile,BufRead * setlocal formatoptions-=cro

" nnoremap <leader>\ :Copilot enable<CR>
" alternativa a TAB per accettare il suggerimento
imap <silent><script><expr> <C-J> copilot#Accept("\<CR>")

let g:NERDCommentEmptyLines = 1
" Enable trimming of trailing whitespace when uncommenting
" let g:NERDTrimTrailingWhitespace = 1

let g:copilot_enabled = 0

" bin to hex
nnoremap ,bh :%!xxd<CR>
nnoremap ,bb :%!xxd -r<CR>

" search and replace
vnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>

" copy paragraph below
nnoremap ,y yap)p
