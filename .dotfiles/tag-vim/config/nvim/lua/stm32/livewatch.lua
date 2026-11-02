-- Live watch: show globals / peripheral registers while the MCU keeps running.
-- Addresses and types come from the ELF (arm-none-eabi-gdb -batch), values are read
-- through OpenOCD's TCL port (6666), so it works next to an nvim-dap session on :3333.
--
--   :LiveWatch                     toggle window (and polling)
--   :LiveWatch add <expr>          C expression with a fixed address, e.g. FOCVars[0].Iqd.q, TIM3->CNT
--   :LiveWatch add [name:] <expr> => <lua formula of x>
--                                  e.g.  enc_deg: TIM3->CNT => band(x, 0xffff) * 360 / 1024
--                                        enc_A: GPIOC->IDR => bit(x, 6)
--                                  helpers: band bor bxor rshift lshift bit(x, n), math.*
--   :LiveWatch addr <0xADDR> [name] [8|16|32]
--   :LiveWatch del <name|index>    (or `dd` in the window)
--   :LiveWatch period <ms>
--   :LiveWatch resolve             re-read addresses/types from the ELF
--   :LiveWatch pick                fuzzy list of global variables (telescope)
-- In the window: a = add (with <Tab> completion), f = pick, dd = delete, q = close

local M = {}
local uv = vim.loop
local ffi = require('ffi')

local cfg = {
  host = '127.0.0.1',
  port = 6666,
  period = 100,
  retry_ms = 2000,
  width = 60,
}

local watches = {}
local conn = { tcp = nil, buf = '', queue = {}, connecting = false, last_try = 0 }
local status = { target = '', elf_mtime = nil, resolving = false }
local timer, buf, win
local ns = vim.api.nvim_create_namespace('livewatch')
local HEADER_LINES = 2

-- persistence -----------------------------------------------------------------

local function save()
  local list = {}
  for _, w in ipairs(watches) do
    table.insert(list, { expr = w.expr, name = w.name, addr = w.fixed_addr, bits = w.fixed_bits,
                         formula = w.formula })
  end
  local f = io.open(cfg.store, 'w')
  if f then
    f:write(vim.fn.json_encode(list))
    f:close()
  end
end

local function load()
  local f = io.open(cfg.store, 'r')
  if not f then
    return nil
  end
  local ok, list = pcall(vim.fn.json_decode, f:read('*a'))
  f:close()
  return ok and list or nil
end

-- formulas ----------------------------------------------------------------------

local formula_env = {
  band = bit.band, bor = bit.bor, bxor = bit.bxor, bnot = bit.bnot,
  rshift = bit.rshift, lshift = bit.lshift,
  bit = function(x, n) return bit.band(bit.rshift(x, n), 1) end,
  math = math, floor = math.floor, abs = math.abs,
}

-- flags(x, {[0x01] = 'A', [0x02] = 'B'}) -> "A|B", "-" when x == 0
function formula_env.flags(x, names)
  if x == 0 then
    return '-'
  end
  local set, rest = {}, x
  local masks = vim.tbl_keys(names)
  table.sort(masks)
  for _, mask in ipairs(masks) do
    if bit.band(x, mask) ~= 0 then
      table.insert(set, names[mask])
      rest = bit.band(rest, bit.bnot(mask))
    end
  end
  if rest ~= 0 then
    table.insert(set, string.format('0x%x', rest))
  end
  return table.concat(set, '|')
end

-- compile "band(x, 0xffff) * 360 / 1024" into a function of x (nil + message on error)
local function compile_formula(formula)
  local fn, err = loadstring('local x = ...; return ' .. formula, 'livewatch')
  if not fn then
    return nil, err
  end
  setfenv(fn, formula_env)
  return fn
end

-- type decoding ---------------------------------------------------------------

local function parse_enum(body)
  local names, n = {}, -1
  for item in body:gmatch('[^,]+') do
    local name, val = item:match('^%s*([%w_]+)%s*=%s*(-?%d+)')
    if name then
      n = tonumber(val)
    else
      name = item:match('^%s*([%w_]+)')
      n = n + 1
    end
    if name then
      names[n] = name
    end
  end
  return names
end

-- set w.kind (+ w.enum) from the gdb `ptype` text and the sizeof value
local function classify(w, ptype)
  local t = ptype:gsub('volatile ', ''):gsub('const ', '')
  local size = w.size
  w.enum = nil
  if t:match('^enum') then
    w.kind = 'enum'
    w.enum = parse_enum(t:match('{(.*)}') or '')
  elseif t:match('^float$') then
    w.kind = 'f32'
  elseif t:match('^double$') then
    w.kind = 'f64'
  elseif t:match('%*') or t:match('%(') then
    w.kind = 'ptr'
  elseif t:match('^struct') or t:match('^union') or t:match('%[') or size > 4 then
    w.kind = 'raw'
  elseif t:match('unsigned') or t == 'char' or t == '_Bool' or t == 'bool' then
    w.kind = 'u'
  else
    w.kind = 'i'
  end
end

local function to_signed(v, bits)
  if v >= 2 ^ (bits - 1) then
    return v - 2 ^ bits
  end
  return v
end

local f32u = ffi.new('union { uint32_t u; float f; }')
local f64u = ffi.new('union { uint32_t u[2]; double d; }')

-- bytes (little endian, list of numbers) -> display string, numeric value (for formulas)
local function format_value(w, bytes)
  local size = #bytes
  local v = 0
  for i = size, 1, -1 do
    v = v * 256 + bytes[i]
  end
  local hex = string.format('0x%0' .. (size * 2) .. 'x', v)
  if w.kind == 'f32' then
    f32u.u = v
    return string.format('%.6g', f32u.f), f32u.f
  elseif w.kind == 'f64' then
    local lo, hi = 0, 0
    for i = 4, 1, -1 do lo = lo * 256 + bytes[i] end
    for i = 8, 5, -1 do hi = hi * 256 + bytes[i] end
    f64u.u[0], f64u.u[1] = lo, hi
    return string.format('%.9g', f64u.d), f64u.d
  elseif w.kind == 'enum' then
    local name = w.enum and w.enum[v]
    return name and string.format('%s (%d)', name, v) or string.format('%d', v), v
  elseif w.kind == 'i' then
    local s = to_signed(v, size * 8)
    return string.format('%.0f  %s', s, hex), s
  elseif w.kind == 'u' then
    return string.format('%.0f  %s', v, hex), v
  elseif w.kind == 'ptr' then
    return hex, v
  end
  -- raw: hex bytes grouped in 32-bit little-endian words
  local words = {}
  for i = 1, size, 4 do
    local word = 0
    for j = math.min(i + 3, size), i, -1 do
      word = word * 256 + bytes[j]
    end
    table.insert(words, string.format('%08x', word))
  end
  return table.concat(words, ' ')
end

-- reading through OpenOCD ----------------------------------------------------

-- read_memory command for a watch, and how to turn its reply into bytes
local function read_cmd(w)
  local size = math.min(w.size, 64)
  local bits = w.fixed_bits or 8
  if not w.fixed_bits and w.addr % 4 == 0 and size % 4 == 0 then
    bits = 32
  elseif not w.fixed_bits and w.addr % 2 == 0 and size % 2 == 0 then
    bits = 16
  end
  return string.format('read_memory 0x%x %d %d', w.addr, bits, size * 8 / bits), bits
end

local function reply_to_bytes(reply, bits)
  local bytes = {}
  for tok in reply:gmatch('%S+') do
    local v = tonumber(tok)
    if not v or not tok:match('^0x%x+$') then
      return nil
    end
    for _ = 1, bits / 8 do
      table.insert(bytes, v % 256)
      v = math.floor(v / 256)
    end
  end
  return #bytes > 0 and bytes or nil
end

local render

local function disconnect()
  if conn.tcp then
    if not conn.tcp:is_closing() then
      conn.tcp:close()
    end
  end
  conn.tcp, conn.buf, conn.queue = nil, '', {}
  status.target = ''
end

local function send(cmd, cb)
  table.insert(conn.queue, cb)
  conn.tcp:write(cmd .. '\26')
end

local function connect()
  conn.connecting, conn.last_try = true, uv.now()
  local tcp = uv.new_tcp()
  tcp:connect(cfg.host, cfg.port, function(err)
    conn.connecting = false
    if err then
      tcp:close()
      return
    end
    conn.tcp, conn.buf, conn.queue = tcp, '', {}
    tcp:read_start(function(rerr, data)
      if rerr or not data then
        vim.schedule(disconnect)
        return
      end
      conn.buf = conn.buf .. data
      while true do
        local i = conn.buf:find('\26', 1, true)
        if not i then
          break
        end
        local reply = conn.buf:sub(1, i - 1)
        conn.buf = conn.buf:sub(i + 1)
        local cb = table.remove(conn.queue, 1)
        if cb then
          vim.schedule(function() cb(reply) end)
        end
      end
    end)
  end)
end

-- symbol resolution with gdb ---------------------------------------------------

local function resolve(list)
  list = list or watches
  local todo = {}
  for _, w in ipairs(list) do
    if not w.fixed_addr then
      table.insert(todo, w)
    end
  end
  if #todo == 0 then
    return
  end
  if status.resolving then
    status.pending = true -- run again (for everything) when the current gdb exits
    return
  end
  status.resolving = true
  -- 2>&1 keeps gdb's error messages in order with the markers
  local args = { 'sh', '-c', 'exec "$@" 2>&1', 'sh', cfg.gdb, '-batch', '-nx', cfg.elf, '-ex', 'list main,main' }
  for i, w in ipairs(todo) do
    vim.list_extend(args, {
      '-ex', 'echo @@W' .. i .. '\\n',
      '-ex', 'print/x &(' .. w.expr .. ')',
      '-ex', 'print sizeof(' .. w.expr .. ')',
      '-ex', 'ptype ' .. w.expr,
    })
  end
  vim.list_extend(args, { '-ex', 'echo @@W0\\n' })
  vim.fn.jobstart(args, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local text = table.concat(data, '\n')
      for i, w in ipairs(todo) do
        local chunk = text:match('@@W' .. i .. '\n(.-)@@W') or ''
        local addr = chunk:match('%$%d+ = [^\n]-(0x%x+)')
        local size = chunk:match('%$%d+ = (%d+)\n')
        local ptype = chunk:match('type = ([^\n]+)')
        if chunk:match('type = enum') then
          ptype = chunk:match('type = (enum.-})') or ptype
        end
        if addr and size and ptype then
          w.addr, w.size, w.err = tonumber(addr), tonumber(size), nil
          classify(w, ptype)
        else
          w.addr, w.err = nil, (chunk:match('^%s*([^\n]+)') or 'cannot resolve')
        end
        w.display = nil
      end
    end,
    on_exit = function()
      status.resolving = false
      local st = uv.fs_stat(cfg.elf)
      status.elf_mtime = st and (st.mtime.sec .. '.' .. st.mtime.nsec)
      if status.pending then
        status.pending = false
        resolve()
      end
      render()
    end,
  })
end

local function check_elf()
  local st = uv.fs_stat(cfg.elf)
  local mtime = st and (st.mtime.sec .. '.' .. st.mtime.nsec)
  if mtime and status.elf_mtime and mtime ~= status.elf_mtime then
    resolve()
  end
end

-- picking expressions -------------------------------------------------------------

-- gdb's own completion: variables, struct fields, register macros (TIM3->C...)
local function gdb_complete(lead)
  local out = vim.fn.systemlist({ cfg.gdb, '-batch', '-nx', cfg.elf,
                                  '-ex', 'list main,main', '-ex', 'complete print ' .. lead })
  local items = {}
  for _, line in ipairs(out) do
    local e = line:match('^print (.+)$')
    if e then
      table.insert(items, e)
    end
  end
  return items
end

-- C expression under the cursor: on `q` in FOCVars[M1].Iqd.q -> the whole expression,
-- on `Iqd` -> FOCVars[M1].Iqd, on `FOCVars` -> FOCVars[M1]
local function expr_at_cursor()
  local ok, node = pcall(vim.treesitter.get_node)
  if ok and node then
    if node:type() == 'field_identifier' then
      node = node:parent()
    end
    local parent = node:parent()
    while parent and parent:type() == 'subscript_expression' and parent:named_child(0)
          and parent:named_child(0):id() == node:id() do
      node, parent = parent, parent:parent()
    end
    local t = node:type()
    if t == 'identifier' or t == 'field_expression' or t == 'subscript_expression' then
      return vim.treesitter.get_node_text(node, 0)
    end
  end
  return vim.fn.expand('<cWORD>'):match('[%a_][%w_%.%[%]>%-]*')
end

-- prompt with <Tab> completion
function M.prompt(default)
  vim.ui.input({ prompt = 'LiveWatch add: ', default = default,
                 completion = 'customlist,v:lua.LiveWatchComplete' }, function(text)
    if text and vim.trim(text) ~= '' then
      M.add(text)
    end
  end)
end

function M.add_at_cursor()
  local expr = expr_at_cursor()
  if not expr or expr == '' then
    vim.notify('LiveWatch: no C expression under the cursor', vim.log.levels.WARN)
    return
  end
  M.add(expr)
  vim.notify('LiveWatch: added ' .. expr)
end

function M.prompt_at_cursor()
  M.prompt(expr_at_cursor())
end

-- fuzzy list of the global variables in the ELF; the choice opens the prompt
-- (Enter to add, or type `.` + <Tab> to go into a struct)
function M.pick()
  local nm = cfg.gdb:gsub('gdb$', 'nm')
  local names = {}
  for _, line in ipairs(vim.fn.systemlist({ nm, '--defined-only', cfg.elf })) do
    local kind, name = line:match('^%x+ (%a) ([%w_]+)$')
    if kind and kind:match('[bBdD]') then
      table.insert(names, name)
    end
  end
  table.sort(names)
  local has_telescope, pickers = pcall(require, 'telescope.pickers')
  if not has_telescope then
    vim.ui.select(names, { prompt = 'LiveWatch: global variable' }, function(choice)
      if choice then
        M.prompt(choice)
      end
    end)
    return
  end
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  pickers.new({}, {
    prompt_title = 'LiveWatch: global variables',
    finder = finders.new_table({ results = names }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_buf)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_buf)
        if entry then
          vim.schedule(function() M.prompt(entry[1]) end)
        end
      end)
      return true
    end,
  }):find()
end

-- window ------------------------------------------------------------------------

local function watch_at_cursor()
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(win)[1]
  return row - HEADER_LINES
end

local function ensure_buf()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, '[LiveWatch]')
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].filetype = 'livewatch'
  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set('n', 'dd', function()
    local i = watch_at_cursor()
    if i and watches[i] then
      M.del(tostring(i))
    end
  end, opts)
  vim.keymap.set('n', 'a', function() M.prompt() end, opts)
  vim.keymap.set('n', 'f', function() M.pick() end, opts)
  vim.keymap.set('n', 'q', function() M.close() end, opts)
  return buf
end

render = function()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local state = conn.tcp and ('connected, ' .. (status.target ~= '' and status.target or '?')) or 'disconnected (OpenOCD :6666)'
  local lines = {
    string.format('LiveWatch  [%s]  %d ms', state, cfg.period),
    string.rep('-', cfg.width - 2),
  }
  local name_width = 8
  for _, w in ipairs(watches) do
    name_width = math.max(name_width, #w.name)
  end
  for _, w in ipairs(watches) do
    local value = w.err or w.ferr or w.read_err or w.display or (w.addr and '...' or 'resolving')
    table.insert(lines, string.format('%-' .. name_width .. 's  %s', w.name, value))
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, conn.tcp and 'Title' or 'WarningMsg', 0, 0, -1)
  for i, w in ipairs(watches) do
    local hl = (w.err or w.ferr or w.read_err) and 'ErrorMsg' or (w.changed and 'DiffChange' or nil)
    if hl then
      vim.api.nvim_buf_add_highlight(buf, ns, hl, HEADER_LINES + i - 1, 0, -1)
    end
  end
end

-- polling -------------------------------------------------------------------------

local function tick()
  check_elf()
  if not conn.tcp then
    if not conn.connecting and uv.now() - conn.last_try >= cfg.retry_ms then
      connect()
    end
    render()
    return
  end
  if #conn.queue > 0 then
    return -- previous round still in flight
  end
  send('[target current] curstate', function(reply) status.target = reply end)
  for _, w in ipairs(watches) do
    if w.addr then
      local cmd, bits = read_cmd(w)
      send(cmd, function(reply)
        local bytes = reply_to_bytes(reply, bits)
        if not bytes then
          w.read_err = vim.trim(reply):gsub('\n', ' ')
          return
        end
        local display, num = format_value(w, bytes)
        if w.fn then
          local ok, res = pcall(w.fn, num)
          if not ok then
            display = 'formula error: ' .. tostring(res)
          elseif type(res) == 'number' then
            display = string.format('%.6g', res)
          else
            display = tostring(res)
          end
        end
        w.read_err = nil
        w.changed = w.display ~= nil and display ~= w.display
        w.display = display
      end)
    end
  end
  send('set _livewatch_ 0', function() render() end)
end

local function start_timer()
  if timer then
    return
  end
  timer = uv.new_timer()
  timer:start(0, cfg.period, vim.schedule_wrap(tick))
end

local function stop_timer()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
  disconnect()
end

-- public API -------------------------------------------------------------------------

function M.open()
  ensure_buf()
  if win and vim.api.nvim_win_is_valid(win) then
    return
  end
  local prev = vim.api.nvim_get_current_win()
  vim.cmd('botright vertical ' .. cfg.width .. 'split')
  win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  for opt, val in pairs({ number = false, relativenumber = false, wrap = false, winfixwidth = true,
                          signcolumn = 'no', cursorline = true, spell = false }) do
    vim.wo[win][opt] = val
  end
  vim.api.nvim_set_current_win(prev)
  if not status.elf_mtime then
    resolve()
  end
  render()
  start_timer()
end

function M.close()
  stop_timer()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  win = nil
end

function M.toggle()
  if win and vim.api.nvim_win_is_valid(win) then
    M.close()
  else
    M.open()
  end
end

-- attach a compiled formula to a watch (errors are shown in its line)
local function set_formula(w, formula)
  w.formula, w.fn, w.ferr = formula, nil, nil
  if formula then
    local fn, err = compile_formula(formula)
    w.fn = fn
    if not fn then
      w.ferr = 'formula: ' .. err
    end
  end
end

-- "[name:] <C expr> [=> <lua formula>]" -> watch table
local function parse_spec(text, name)
  text = vim.trim(text)
  local label, rest = text:match('^([%w_]+):%s+(.+)$')
  if label then
    name, text = label, rest
  end
  local expr, formula = text:match('^(.-)%s*=>%s*(.+)$')
  expr = expr or text
  local w = { expr = expr, name = name or (formula and (expr .. ' => ' .. formula) or expr) }
  set_formula(w, formula)
  return w
end

function M.add(text, name)
  local w = parse_spec(text, name)
  table.insert(watches, w)
  save()
  resolve({ w })
  render()
end

function M.add_addr(addr, name, bits)
  local a = tonumber(addr)
  if not a then
    vim.notify('LiveWatch: bad address ' .. tostring(addr), vim.log.levels.ERROR)
    return
  end
  bits = tonumber(bits) or 32
  local w = { expr = string.format('0x%08x', a), name = name or string.format('0x%08x', a),
              fixed_addr = a, fixed_bits = bits, addr = a, size = bits / 8, kind = 'u' }
  table.insert(watches, w)
  save()
  render()
end

function M.del(key)
  local i = tonumber(key)
  if not i then
    for j, w in ipairs(watches) do
      if w.name == key or w.expr == key then
        i = j
      end
    end
  end
  if i and watches[i] then
    table.remove(watches, i)
    save()
    render()
  end
end

function M.stop()
  M.close()
end

function M.setup(opts)
  cfg = vim.tbl_extend('force', cfg, opts or {})
  cfg.store = cfg.store or (cfg.root .. '/.livewatch.json')
  for k, v in pairs(cfg.helpers or {}) do
    formula_env[k] = v -- project-specific names usable in formulas
  end
  -- completion for the add prompt (vim.ui.input 'customlist,v:lua.LiveWatchComplete')
  _G.LiveWatchComplete = function(lead)
    return gdb_complete(lead)
  end
  watches = {}
  for _, item in ipairs(load() or cfg.defaults or {}) do
    if item.addr then
      table.insert(watches, { expr = string.format('0x%08x', item.addr), name = item.name or item.expr,
                              fixed_addr = item.addr, fixed_bits = item.bits or 32, addr = item.addr,
                              size = (item.bits or 32) / 8, kind = 'u' })
    elseif item.formula then
      local w = { expr = item.expr, name = item.name or item.expr }
      set_formula(w, item.formula)
      table.insert(watches, w)
    else
      -- also fixes entries saved whole ("name: expr => formula") by older versions
      table.insert(watches, parse_spec(item.expr, item.name ~= item.expr and item.name or nil))
    end
  end

  vim.api.nvim_create_user_command('LiveWatch', function(c)
    local sub, rest = c.args:match('^(%S*)%s*(.-)$')
    if sub == '' then
      M.toggle()
    elseif sub == 'add' then
      M.add(rest)
    elseif sub == 'addr' then
      M.add_addr(unpack(vim.split(rest, '%s+')))
    elseif sub == 'del' then
      M.del(rest)
    elseif sub == 'period' then
      cfg.period = tonumber(rest) or cfg.period
      if timer then
        stop_timer()
        start_timer()
      end
    elseif sub == 'resolve' then
      resolve()
    elseif sub == 'pick' then
      M.pick()
    else
      vim.notify('LiveWatch: unknown subcommand ' .. sub, vim.log.levels.ERROR)
    end
  end, {
    nargs = '*',
    complete = function(lead, line)
      if line:match('^%S+%s+%S*$') then
        return vim.tbl_filter(function(s) return s:find(lead, 1, true) == 1 end,
                              { 'add', 'addr', 'del', 'period', 'resolve', 'pick' })
      end
      if line:match('^%S+%s+add%s') then
        return gdb_complete(lead)
      end
      return {}
    end,
  })
  return M
end

return M
