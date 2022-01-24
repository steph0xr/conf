set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc


"vim.lsp - nvim-lspconfig
" lua require'lspconfig'.clangd.setup{cmd = { "clangd-xtensa", "--background-index", "--query-driver=/home/steph/.espressif/tools/xtensa-esp32-elf/esp-2020r3-8.4.0/xtensa-esp32-elf/bin/xtensa-esp32-elf-*" }}
"lua require'lspconfig'.clangd.setup{cmd = { "clangd", "--background-index", "--query-driver=/usr/bin/gcc"}}
lua require'lspconfig'.clangd.setup{cmd = { "clangd", "--background-index" }}

" lua vim.lsp.set_log_level("debug")
"

" "nvim-completion
" autocmd BufEnter * lua require'completion'.on_attach()
" " lua vim.api.nvim_buf_set_option(0, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
" set completeopt=menuone,noinsert,noselect
" let g:completion_sorting = "length"
" let g:completion_matching_strategy_list = ['exact', 'substring', 'fuzzy']
" let g:completion_trigger_character = ['::'] " c++ class
" let g:completion_enable_auto_popup = 1
" " completion with tab
" inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
" inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
" " completion trigger in insert mode
" imap <tab> <Plug>(completion_smart_tab)
" imap <s-tab> <Plug>(completion_smart_s_tab)
" " Avoid showing message extra message when using completion
" set shortmess+=c

nnoremap gd :lua vim.lsp.buf.definition()<CR>
nnoremap gi :lua vim.lsp.buf.implementation()<CR>
nnoremap gr :lua vim.lsp.buf.references()<CR>
nnoremap gn :lua vim.lsp.buf.rename()<CR>
nnoremap gh :lua vim.lsp.buf.hover()<CR>
nnoremap gca :lua vim.lsp.buf.code_action()<CR>
" nnoremap gsd :lua vim.lsp.util.show_line_diagnostics(); vim.lsp.util.show_line_diagnostics()<CR>
" nnoremap gsh :lua vim.lsp.buf.signature_help()<CR>
nnoremap gn :lua vim.lsp.diagnostic.goto_next()<CR>
nnoremap grn :lua vim.lsp.buf.rename()<CR>
nnoremap gc :lua vim.lsp.buf.completion()<CR>
nnoremap <leader>LS :LspStop<CR>
nnoremap <leader>LL :lua vim.cmd('e'..vim.lsp.get_log_path())<CR>

"nnoremap <silent> vd <cmd>lua vim.lsp.buf.definition()<CR>
"nnoremap <silent> gD <cmd>lua vim.lsp.buf.declaration()<CR>
"nnoremap <silent> gr <cmd>lua vim.lsp.buf.references()<CR>
"nnoremap <silent> gi <cmd>lua vim.lsp.buf.implementation()<CR>
"nnoremap <silent> K <cmd>lua vim.lsp.buf.hover()<CR>
"nnoremap <silent> <C-k> <cmd>lua vim.lsp.buf.signature_help()<CR>
"nnoremap <silent> <C-n> <cmd>lua vim.lsp.diagnostic.goto_prev()<CR>
"nnoremap <silent> <C-p> <cmd>lua vim.lsp.diagnostic.goto_next()<CR>
"


lua <<EOF
-- luasnip setup
-- local luasnip = require 'luasnip'
-- local vsnip = require 'vsnip'

-- Setup nvim-cmp.
local cmp = require 'cmp'
cmp.setup({
	snippet = {
		expand = function(args)
			-- require("luasnip").lsp_expand(args.body)
			vim.fn["vsnip#anonymous"](args.body)
			-- vim.fn["UltiSnips#Anon"](args.body)
		end,
	},
	mapping = {
		["<C-u>"] = cmp.mapping.scroll_docs(-4),
		["<C-d>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.close(),
	},

	sources = {
		{ name = 'vsnip' },
		-- { name = "nvim_lsp" },
		-- { name = "luasnip" },
		{ name = "buffer" },
		-- { name = 'ultisnips' },
	},
})
EOF

