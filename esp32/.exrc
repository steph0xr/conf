"debug
let g:termdebugger = "/home/steph/.espressif/tools/xtensa-esp32-elf/esp-2020r3-8.4.0/xtensa-esp32-elf/bin/xtensa-esp32-elf-gdb"

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
nnoremap ,m :Make -C build<CR><CR>:cw<CR>
nnoremap ,k :Make -v -C build<CR><CR>:cw<CR>
nnoremap ,M :make! -C build<CR><CR>:cw<CR>
set makeprg=ninja
"nnoremap ,cw :CMakeClean<CR>:CMakeGenerate<CR>:make! -C build<CR><CR>:cw<CR>

" ESP32
nnoremap ,cv :!cd build && ninja clean<CR>
"nnoremap ,cb :CMakeBuild -v<CR>
nnoremap ,ce :!cd build && ninja<CR>
nnoremap ,ca :!cmake -GNinja -B ../build && cmake --build ../build -v<CR>
" nnoremap ,j :!esp-app-flash<CR>
nnoremap ,l :Dispatch idf.py app-flash<CR>
nnoremap ,L :Dispatch idf.py flash<CR>
nnoremap ,j :Dispatch esp-app-flash<CR>
nnoremap ,J :Dispatch esp-flash<CR>
nnoremap ,r :silent !esp-reset<CR>
nnoremap ,d :Dispatch espcoredump.py --port /dev/ttyUSB1 dbg_corefile build/mini-gateway.elf -o 4284416 --save-core coredump<CR>
nnoremap ,e :Dispatch idf.py erase_flash<CR>
