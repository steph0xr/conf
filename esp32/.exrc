"Termdebug
packadd termdebug
let g:termdebugger = "xtensa-esp32-elf-gdb"
nnoremap ùd :Termdebug -q<CR>G<C-w>j<CR>:term<CR>Asu1<CR><C-\><C-n>G
nnoremap ùr :Termdebug -q<CR>G<C-w>j<CR>:term<CR>Asu1<CR><C-\><C-n>G<C-w>l:Continue<CR>
nnoremap ùt :Termdebug -q<CR>G<C-w>j<CR>:term<CR>Asu1<CR><C-\><C-n>G:call TermDebugSendCommand('esp-all')<CR>
nnoremap ùa :call TermDebugSendCommand('eflash')<CR>
nnoremap ùw :call TermDebugSendCommand('esp-all')<CR>
nnoremap ùq :call TermDebugSendCommand('q')<CR>:Gdb<CR>:call TermDebugSendCommand('save break .breakpoints')<CR>:q<CR>A<C-a>x<CR><C-\><C-n>:q<CR>
nnoremap ùi :call TermDebugSendCommand('esp-restart')<CR>
nnoremap ùz :call TermDebugSendCommand('esp-restart-continue')<CR>


" nnoremap ùd :Termdebug $velf<CR>


"xtensa-clang
let g:ycm_clangd_uses_ycmd_caching = 0
let g:ycm_clangd_binary_path = "clangd-xtensa"
let g:ycm_clangd_args = ['-log=verbose', '-pretty'] "-background-index

"formatting
let g:clang_format#detect_style_file = 1
let g:clang_format#enable_fallback_style = 0

"cdelledonne/vim-cmake
let g:cmake_default_config = 'build'
"let g:cmake_generate_options = ['-GNinja', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON']
let g:cmake_generate_options = ['-GNinja', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON', '-DPYTHON_DEPS_CHECKED=1', '-DESP_PLATFORM=1', '-DIDF_TARGET=esp32', '-DCCACHE_ENABLE=1']
let g:cmake_root_markers = ['build']
let g:cmake_link_compile_commands = 1
let g:cmake_jump = 1
nnoremap ,cb :CMakeBuild<CR>
nnoremap ,cx :CMakeClean<CR>
nnoremap ,cz :CMakeClose<CR>
nnoremap ,c :CMakeGenerate!<CR>
" Make dispatch to tmux
nnoremap ,m :wa<CR> :Make -C build<CR><CR>:cw<CR>
nnoremap ,M :Make -v -C build<CR><CR>:cw<CR>
" nnoremap , :make! -C build<CR><CR>:cw<CR>
set makeprg=ninja
"nnoremap ,cw :CMakeClean<CR>:CMakeGenerate<CR>:make! -C build<CR><CR>:cw<CR>

" ESP32
nnoremap ,cv :!cd build && ninja clean<CR>
"nnoremap ,cb :CMakeBuild -v<CR>
nnoremap ,ce :!cd build && ninja<CR>
nnoremap ,ca :!cmake -GNinja -B ../build && cmake --build ../build -v<CR>
" nnoremap ,j :!esp-app-flash<CR>
" nnoremap ,J :Dispatch idf.py app-flash<CR>
nnoremap ,J :Dispatch idf.py flash monitor<CR>
nnoremap ,aa :Dispatch! idf.py flash monitor<CR>
nnoremap ,Z :Dispatch idf.py monitor<CR>
nnoremap ,zz :Dispatch! idf.py monitor<CR>
nnoremap \o :Dispatch openocd -f .conf/openocd.cfg<CR><leader>ddd
nnoremap ,k :exe "!tmux send -t make 'A'"<CR>:exe "!tmux send -t make 'C-]'"<CR><C-L>
nnoremap ,< :exe "!tmux select-window -t make"<CR>
" nnoremap ,< :exe "!tmux set mouse on"<CR>
nmap ,a ,k,aa,<
nmap ,z ,k,zz,<

" nnoremap ,k :Dispatch! idf.py monitor<CR>
nnoremap ,l :Dispatch .conf/esp-app-flash.sh<CR>
nnoremap ,L :Dispatch .conf/esp-flash.sh<CR>
nnoremap ,r :silent !esp-reset<CR>
" nnoremap ,d :Dispatch espcoredump.py --port /dev/ttyUSB1 dbg_corefile build/mini-gateway.elf -o 4284416 --save-core coredump<CR>
nnoremap ,ee :Dispatch idf.py erase_flash<CR>
nnoremap ,eo :Dispatch idf.py erase_otadata<CR>
