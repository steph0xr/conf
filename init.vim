set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

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



lua << EOF
-- Setup nvim-cmp.
local cmp = require 'cmp'
local select_opts = {behavior = cmp.SelectBehavior.Select}

cmp.setup({
	mapping = {
    ['<C-p>'] = cmp.mapping.select_prev_item(select_opts),
    ['<C-n>'] = cmp.mapping.select_next_item(select_opts),
		["<C-u>"] = cmp.mapping.scroll_docs(-4),
		["<C-d>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.close(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
	},
	sources = {
		{ name = "nvim_lsp" },
--		{ name = "buffer" },
--		{ name = "luasnip" },
		-- { name = 'ultisnips' },
		-- { name = 'vsnip' },
	},
  formatting = {
    fields = {'menu', 'abbr', 'kind'},
    format = function(entry, item)
      local menu_icon = {
        nvim_lsp = '⋗',
        buffer = 'Ω',
        path = '🖫',
      }

      item.menu = menu_icon[entry.source.name]
      return item
    end,
  },
  window = {
    -- completion = cmp.config.window.bordered(),
    -- documentation = cmp.config.window.bordered(),
    },
})
EOF


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
local elf = ""
local f, err = io.open(env_file, "r")
if f then
  local esp_env = f:read("*all")
  --print(esp_env)
  local data = vim.fn.json_decode(esp_env)
  local elf = vim.fn.get(data, 'app_elf', {})
  --print(elf)
  f:close()
--else
--   print("no project_description.json found.")
end

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
    program = string.format(vim.fn.getcwd() .. '/build/hello_world.elf'),
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



require('rose-pine').setup({
	--- @usage 'main' | 'moon'
	dark_variant = 'moon',
	bold_vert_split = false,
	dim_nc_background = false,
	disable_background = true,
	disable_float_background = false,
	disable_italics = false,

	--- @usage string hex value or named color from rosepinetheme.com/palette
	groups = {
		background = 'base',
		panel = 'surface',
		border = 'highlight_med',
		comment = 'muted',
		link = 'iris',
		punctuation = 'subtle',

		error = 'love',
		hint = 'iris',
		info = 'foam',
		warn = 'gold',

		headings = {
			h1 = 'iris',
			h2 = 'foam',
			h3 = 'rose',
			h4 = 'gold',
			h5 = 'pine',
			h6 = 'foam',
		}
		-- or set all headings at once
		-- headings = 'subtle'
	},

	-- Change specific vim highlight groups
	highlight_groups = {
		ColorColumn = { bg = 'rose' }
	}
})

-- set colorscheme after options
vim.cmd('colorscheme rose-pine')

EOF


