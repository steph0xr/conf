set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

nnoremap gd :lua vim.lsp.buf.definition()<CR>
" nnoremap gi :lua vim.lsp.buf.implementation()<CR>
nnoremap gr :lua vim.lsp.buf.references()<CR>
nnoremap gn :lua vim.lsp.buf.rename()<CR>
nnoremap gh :lua vim.lsp.buf.hover()<CR>
nnoremap gca :lua vim.lsp.buf.code_action()<CR>
" nnoremap gsd :lua vim.lsp.util.show_line_diagnostics(); vim.lsp.util.show_line_diagnostics()<CR>
" nnoremap gsh :lua vim.lsp.buf.signature_help()<CR>
nnoremap gn :lua vim.diagnostic.jump({ count = 1, float = true })<CR>
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


"lua require('dap-python').setup('~/.virtualenvs/debugpy/bin/python')
set completeopt=menu,menuone,noselect

"vim.lsp - nvim-lspconfig
lua <<EOF

local clangd = {
   cmd = {
    "clangd", 
    "--background-index", 
    "--pch-storage=memory",
    "--limit-results=20",
    -- let clangd ask the ARM cross gcc (STM32CubeCLT) for its system headers
    "--query-driver=/opt/st/stm32cubeclt/GNU-tools-for-STM32/bin/arm-none-eabi-*",
--     "--query-driver=/home/steph/.espressif/tools/xtensa-esp32-elf/esp-2022r1-11.2.0/xtensa-esp32-elf/bin/xtensa-esp32-elf-gcc"
  },
--  cmd = { 
    -- "clangd-xtensa",
 --   "clangd" 
    -- "--background-index"
--  },
}

-- per project root: ESP-IDF projects get Espressif's esp-clangd (Xtensa / RISC-V target, ESP gcc
-- headers), see mcu/esp32.lua clangd_cmd; everything else the clangd above (ARM query-driver)
local clangd_default = clangd.cmd
clangd.cmd = function(dispatchers, config)
  local argv, env = require('mcu.esp32').clangd_cmd(config.root_dir)
  return vim.lsp.rpc.start(argv or clangd_default, dispatchers, {
    cwd = config.cmd_cwd,
    env = vim.tbl_extend('force', config.cmd_env or {}, env or {}),
    detached = config.detached,
  })
end
-- nvim-project.lua / sdkconfig: MCU project folders without .clangd / .git still get a root
clangd.root_markers = { '.clangd', '.clang-tidy', '.clang-format', 'compile_commands.json',
  'compile_flags.txt', 'configure.ac', 'nvim-project.lua', 'sdkconfig', '.git' }

-- built-in LSP config (nvim-lspconfig only supplies the server defaults in lsp/*.lua)
vim.lsp.config('clangd', clangd)
vim.lsp.enable({ 'clangd', 'pyright' })

-- diagnostic message at the end of the line, as before nvim 0.11 (which turned it off by default)
vim.diagnostic.config({ virtual_text = true })

EOF

" lua vim.lsp.set_log_level("debug")



lua << EOF
-- Setup nvim-cmp.
local cmp = require 'cmp'
-- the following will not autocomplete by default, but needs CR to be hit
-- local select_opts = {behavior = cmp.SelectBehavior.Select}

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
		{ name = "buffer" },
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


lua require('dap-python').setup('python')
lua require("dapui").setup()

nnoremap <silent> <leader>du <Cmd>lua require'dapui'.toggle()<CR>

nnoremap <silent> <leader>dc <Cmd>lua require'dap'.continue()<CR>
nnoremap <silent> <leader>dq <Cmd>lua require'dap'.terminate()<CR>
nnoremap <silent> <leader>dn <Cmd>lua require'dap'.step_over()<CR>
nnoremap <silent> <leader>ds <Cmd>lua require'dap'.step_into()<CR>
nnoremap <silent> <leader>df <Cmd>lua require'dap'.step_out()<CR>
nnoremap <silent> <leader>db <Cmd>lua require'dap'.toggle_breakpoint()<CR>
nnoremap <silent> <leader>dB <Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>
nnoremap <silent> <leader>dlp <Cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>
nnoremap <silent> <leader>dr <Cmd>lua require'dap'.repl.open()<CR>
" run the last config again (= dap-ui's round arrow). With that session still active it is stopped
" and relaunched from the original config, so MCU projects flash the new build: <leader>mb, <leader>dl
nnoremap <silent> <leader>dl <Cmd>lua require'dap'.run_last()<CR>
nnoremap <silent> <leader>dh <Cmd>lua require'dap.ui.widgets'.hover()<CR>
nnoremap <silent> <leader>dp <Cmd>lua require'dap.ui.widgets'.preview()<CR>

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

-- c / c++ debug adapter: vscode-cpptools (cppdbg)
-- pick the newest executable OpenDebugAD7, so a cpptools update doesn't break the path
local function find_open_debug_ad7()
  local found = vim.fn.glob(vim.fn.expand('~') .. '/.vscode/extensions/ms-vscode.cpptools-*/debugAdapters/bin/OpenDebugAD7', false, true)
  for i = #found, 1, -1 do
    if vim.fn.executable(found[i]) == 1 then
      return found[i]
    end
  end
  return 'OpenDebugAD7'
end
dap.adapters.cppdbg = {
  id = 'cppdbg',
  type = 'executable',
  command = find_open_debug_ad7(),
}

-- no global configurations: they come per project (nvim-project.lua), see below
dap.configurations.c = {}
dap.configurations.cpp = dap.configurations.c

-- MCU / embedded Linux projects (folders with nvim-project.lua, platform = 'stm32' | 'esp32' | 'linux'):
-- build/flash/OpenOCD/serial/kgdb keymaps and the "STM32 ..." / "ESP32 ..." / "Linux ..." dap
-- configurations. See lua/mcu/init.lua
require('mcu').autoload()



require('rose-pine').setup({
	--- @usage 'main' | 'moon'
	dark_variant = 'moon',
	dim_inactive_windows = false,

	styles = {
		italic = true,
		transparency = true, -- no background: the terminal's (transparent) one shows through
	},

	--- @usage string hex value or named color from rosepinetheme.com/palette
	groups = {
		panel = 'surface',
		border = 'highlight_med',
		link = 'iris',

		error = 'love',
		hint = 'iris',
		info = 'foam',
		warn = 'gold',

		h1 = 'iris',
		h2 = 'foam',
		h3 = 'rose',
		h4 = 'gold',
		h5 = 'pine',
		h6 = 'foam',
	},

	-- Change specific vim highlight groups
	highlight_groups = {
		ColorColumn = { bg = 'rose' },
		Comment = { fg = 'muted' },
		['@punctuation'] = { fg = 'subtle' },
	}
})

-- set colorscheme after options
vim.cmd('colorscheme rose-pine')

vim.cmd([[
highlight DiffAdd    guifg=#73c991 guibg=#262626
highlight DiffDelete guifg=#f14c4c guibg=#262626
highlight DiffChange guifg=#e2c08d guibg=#333343
highlight DiffText   guifg=#569cd6  guibg=#333343
]])


-- telescope keybinding
require("telescope").setup {
  pickers = {
    find_files = {
      mappings = {
        i = {
          ["<C-t>"] = require("telescope.actions.layout").toggle_preview,
          ["<C-j>"] = require("telescope.actions").select_default
        },
      },
    },
    grep_string = {
      mappings = {
        i = {
          ["<C-t>"] = require("telescope.actions.layout").toggle_preview,
          ["<C-j>"] = require("telescope.actions").select_default
        },
      },
    },
    git_branches = {
      mappings = {
        i = {
          ["<C-t>"] = require("telescope.actions.layout").toggle_preview,
          ["<C-j>"] = require("telescope.actions").select_default
        },
      },
    },
  },
}


-- treesitter
-- nvim-treesitter 'main' branch: only parsers + queries, highlight/fold/indent are nvim's own.
-- Parsers for c, lua, vim, vimdoc, query, markdown ship with nvim; others are compiled with the
-- tree-sitter CLI (>= 0.26.1):  :lua require('nvim-treesitter').install({ 'cpp' })
-- Highlight stays off as before (per buffer: :lua vim.treesitter.start()).
require('nvim-treesitter-textobjects').setup {
  select = { lookahead = true }, -- jump forward to the textobj, like targets.vim
  move = { set_jumps = true },
}
local select = require('nvim-treesitter-textobjects.select')
for lhs, query in pairs({
  aa = '@parameter.outer', ia = '@parameter.inner',
  af = '@function.outer', ['if'] = '@function.inner',
  ac = '@class.outer', ic = '@class.inner',
}) do
  vim.keymap.set({ 'x', 'o' }, lhs, function() select.select_textobject(query, 'textobjects') end)
end
local move = require('nvim-treesitter-textobjects.move')
for fn, maps in pairs({
  goto_next_start = { [']m'] = '@function.outer', [']]'] = '@class.outer' },
  goto_next_end = { [']M'] = '@function.outer', [']['] = '@class.outer' },
  goto_previous_start = { ['[m'] = '@function.outer', ['[['] = '@class.outer' },
  goto_previous_end = { ['[M'] = '@function.outer', ['[]'] = '@class.outer' },
}) do
  for lhs, query in pairs(maps) do
    vim.keymap.set({ 'n', 'x', 'o' }, lhs, function() move[fn](query, 'textobjects') end)
  end
end
local swap = require('nvim-treesitter-textobjects.swap')
vim.keymap.set('n', '<leader>a', function() swap.swap_next('@parameter.inner') end)
vim.keymap.set('n', '<leader>A', function() swap.swap_previous('@parameter.inner') end)



EOF



"set foldmethod=expr
"set foldexpr=nvim_treesitter#foldexpr()
"set foldenable
"set foldlevelstart=99  " Start with all folds open

"nnoremap ,ff :setlocal foldmethod=expr<CR>zM
"nnoremap ,f :setlocal foldmethod=syntax<CR>zM


autocmd FileType fugitive,git lua vim.treesitter.stop()

" files on a network mount (gio/gvfs sftp, e.g. the Yocto kernel sources opened by a Linux kgdb
" session): no gitgutter. Its git diff runs synchronously and takes minutes on a remote kernel tree,
" nvim hangs meanwhile. Checked on the real path, so symlinks into /run/user/<uid>/gvfs count too.
augroup no_git_on_gvfs
  autocmd!
  autocmd BufReadPre * if resolve(expand('<afile>:p')) =~# '^/run/user/\d\+/gvfs/' |
        \ let b:gitgutter = {'enabled': 0} | endif
augroup END
