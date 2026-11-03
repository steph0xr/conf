-- Microcontroller projects in nvim: build / flash / OpenOCD / nvim-dap / serial (+ LiveWatch on STM32).
--
-- Loaded from init.vim with  require('mcu').autoload()
-- A folder is an MCU project when it contains nvim-project.lua (when nvim starts there, or on :cd).
-- nvim-project.lua returns a table; `platform` picks the module (lua/mcu/<platform>.lua):
--   platform = 'stm32' (default)  see mcu/stm32.lua
--   platform = 'esp32'            see mcu/esp32.lua
-- The file is read through vim.secure.read, so nvim asks once (and after every change) whether to
-- trust it, like 'exrc'. Load by hand with  :Mcu [dir]

local M = {}

M.PROJECT_FILE = 'nvim-project.lua'
M.root = nil -- project currently loaded

-- nvim-project.lua through the trust database (nil when not trusted / broken)
local function load_project(path)
  local src = vim.secure.read(path)
  if not src then
    vim.notify('mcu: ' .. path .. ' is not trusted, setup skipped (:trust it, then :Mcu)', vim.log.levels.WARN)
    return nil
  end
  local chunk, err = loadstring(src, '@' .. path)
  if not chunk then
    vim.notify('mcu: ' .. err, vim.log.levels.ERROR)
    return nil
  end
  local ok, res = pcall(chunk)
  if not ok or type(res) ~= 'table' then
    vim.notify('mcu: ' .. path .. ': ' .. tostring(res), vim.log.levels.ERROR)
    return nil
  end
  return res
end

-- helpers shared by the platform modules ------------------------------------------------------

function M.map(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { silent = true, desc = desc })
end

-- run argv in a terminal split at the bottom of the screen
function M.term(argv, cwd)
  vim.cmd('botright 10split | enew')
  vim.fn.termopen(argv, { cwd = cwd })
end

-- only one OpenOCD can own the probe and ports 3333/6666: say who has them
function M.openocd_busy()
  local listen = vim.fn.system({ 'ss', '-ltnp' })
  if not (listen:match(':3333%s') or listen:match(':6666%s')) then
    return false
  end
  local who = vim.fn.system({ 'sh', '-c', "pgrep -af '[o]penocd|[S]T-LINK_gdbserver' || ss -ltnp | grep -E ':(3333|6666)\\b'" })
  vim.notify('OpenOCD: ports 3333/6666 already in use by:\n' .. who
             .. 'stop it first (close the other gdbserver terminal, or kill <pid>)', vim.log.levels.ERROR)
  return true
end

-- gdb commands as cppdbg wants them
function M.gdb_cmds(list)
  local out = {}
  for _, c in ipairs(list) do
    table.insert(out, { text = c })
  end
  return out
end

-- put our dap configurations first (choice 1, 2, ...), keep the global ones after them,
-- drop the ones a previous project / reload added
function M.set_dap_configs(list)
  local dap = require('dap')
  local configs = {}
  for _, c in ipairs(list) do
    c.mcu = true -- marker: replaced on the next reload / project
    table.insert(configs, c)
  end
  for _, c in ipairs(dap.configurations.c or {}) do
    if not c.mcu then
      table.insert(configs, c)
    end
  end
  dap.configurations.c = configs
  dap.configurations.cpp = configs
end

-- loading ---------------------------------------------------------------------------------------

function M.setup(root)
  root = vim.fn.fnamemodify(root, ':p'):gsub('/$', '')
  local project = load_project(root .. '/' .. M.PROJECT_FILE)
  if not project then
    return false
  end
  local platform = project.platform or 'stm32'
  local ok, mod = pcall(require, 'mcu.' .. platform)
  if not ok then
    vim.notify('mcu: unknown platform "' .. platform .. '" in ' .. M.PROJECT_FILE .. '\n' .. mod, vim.log.levels.ERROR)
    return false
  end
  M.root = root
  mod.setup(root, project)
  return true
end

-- set up the cwd when it is an MCU project (now and after :cd)
function M.autoload()
  local function try(dir)
    if dir ~= M.root and vim.uv.fs_stat(dir .. '/' .. M.PROJECT_FILE) then
      M.setup(dir)
    end
  end
  local group = vim.api.nvim_create_augroup('mcu_autoload', { clear = true })
  -- after startup, so a project-local .exrc (sourced after init.vim) can't override makeprg & co.
  if vim.v.vim_did_enter == 1 then
    try(vim.fn.getcwd())
  else
    vim.api.nvim_create_autocmd('VimEnter', { group = group, once = true, callback = function() try(vim.fn.getcwd()) end })
  end
  vim.api.nvim_create_autocmd('DirChanged', {
    group = group,
    pattern = 'global',
    callback = function() try(vim.fn.getcwd()) end,
  })
  vim.api.nvim_create_user_command('Mcu', function(c)
    M.setup(c.args ~= '' and c.args or vim.fn.getcwd())
  end, { nargs = '?', complete = 'dir', desc = 'load the MCU (STM32 / ESP32) setup for a project folder' })
end

return M
