set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc


"vim.lsp - nvim-lspconfig
lua <<EOF

local lspconfig = require'lspconfig'.clangd.setup {
--cmd = { "clangd", "--background-index", "--query-driver=/usr/bin/gcc"}
  cmd = { 
    "clangd", 
    "--background-index" 
  },
}
EOF

" lua vim.lsp.set_log_level("debug")
"


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

set completeopt=menu,menuone,noselect

lua <<EOF
-- luasnip setup
-- local luasnip = require 'luasnip'
-- local vsnip = require 'vsnip'

-- local lspkind = require("lspkind")
-- require('lspkind').init({
--     with_text = true,
-- })

-- Setup nvim-cmp.
local cmp = require 'cmp'
local source_mapping = {
	buffer = "[Buffer]",
--	nvim_lsp = "[LSP]",
--	nvim_lua = "[Lua]",
--	cmp_tabnine = "[TN]",
--	path = "[Path]",
}
cmp.setup({
	snippet = {
		expand = function(args)
			require("luasnip").lsp_expand(args.body)
--			vim.fn["vsnip#anonymous"](args.body)
			-- vim.fn["UltiSnips#Anon"](args.body)
		end,
	},
	mapping = {
		["<C-u>"] = cmp.mapping.scroll_docs(-4),
		["<C-d>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.close(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
	},
--  formatting = {
--        format = function(entry, vim_item)
--            vim_item.kind = lspkind.presets.default[vim_item.kind]
--            local menu = source_mapping[entry.source.name]
--            if entry.source.name == 'cmp_tabnine' then
--                if entry.completion_item.data ~= nil and entry.completion_item.data.detail ~= nil then
--                    menu = entry.completion_item.data.detail .. ' ' .. menu
--                end
--                vim_item.kind = ''
--            end
--            vim_item.menu = menu
--            return vim_item
--        end
--  },
	sources = {
		-- { name = 'vsnip' },
		{ name = "nvim_lsp" },
		{ name = "luasnip" },
		{ name = "buffer" },
		-- { name = 'ultisnips' },
	},
})
EOF

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


lua require('dap-python').setup('~/.virtualenvs/debugpy/bin/python')
lua require("dapui").setup()

nnoremap <silent> <leader>du <Cmd>lua require'dapui'.toggle()<CR>

nnoremap <silent> <leader>dc <Cmd>lua require'dap'.continue()<CR>
nnoremap <silent> <leader>ds <Cmd>lua require'dap'.terminate()<CR>
nnoremap <silent> <leader>dn <Cmd>lua require'dap'.step_over()<CR>
nnoremap <silent> <leader>dj <Cmd>lua require'dap'.step_into()<CR>
nnoremap <silent> <leader>dk <Cmd>lua require'dap'.step_out()<CR>
nnoremap <silent> <leader>db <Cmd>lua require'dap'.toggle_breakpoint()<CR>
nnoremap <silent> <leader>dB <Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>
nnoremap <silent> <leader>dlp <Cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>
nnoremap <silent> <leader>dr <Cmd>lua require'dap'.repl.open()<CR>
nnoremap <silent> <leader>dl <Cmd>lua require'dap'.run_last()<CR>

lua <<EOF
-- automatic launch dap-ui 
local dap, dapui = require("dap"), require("dapui")
dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

-- c++ debug adapter configutation
local dap = require('dap')
dap.adapters.cppdbg = {
  id = 'cppdbg',
  type = 'executable',
  command = '/opt/vscode-cpptools/extension/debugAdapters/bin/OpenDebugAD7',
}

local env_file = vim.fn.getcwd() .. '/build/project_description.json'
local esp_env = vim.fn.join(vim.fn.readfile(env_file), "\n")
local data = vim.fn.json_decode(esp_env)
 local elf = vim.fn.get(data, 'app_elf', {})
--print(elf)

local dap = require('dap')
dap.configurations.cpp = {
  -- {
  --   name = "Launch file",
  --   type = "cppdbg",
  --   request = "launch",
  --   program = function()
  --     return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
  --   end,
  --   cwd = '${workspaceFolder}',
  --   stopOnEntry = true,
  -- },
  -- default cmake cpp desktop appl:
  -- {
  --   name = "Launch cmake file",
  --   type = "cppdbg",
  --   request = "launch",
  --   program = vim.fn.getcwd() .. '/build/main/main',
  --   cwd = '${workspaceFolder}',
  --   stopOnEntry = true,
  -- },
  {
    name = 'esp32 Attach to gdbserver :3333',
    type = 'cppdbg',
    request = 'launch',
    MIMode = 'gdb',
    miDebuggerServerAddress = 'localhost:3333',
    miDebuggerPath = 'xtensa-esp32-elf-gdb',
    cwd = '${workspaceFolder}',
    program = string.format(vim.fn.getcwd() .. '/build/%s', elf),
    -- externalConsole = true,
   --setupCommands = {  
     --{ text = 'set remotetimeout 15000' },
     --{ text = 'file build/hello_world.elf' },
     --{ text = 'target remote :3333' },
     --{ text = 'set remote hardware-watchpoint-limit 2'},
     --{ text = 'mon reset halt' },
     --{ text = 'hb app_main' },
     --{ text = 'flushregs' },
     --{ text = '-enable-pretty-printing' }
   --},
    
    logging = { 
      engineLogging = true 
      }
  },
}
dap.configurations.c = dap.configurations.cpp

EOF
