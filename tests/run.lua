vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.o.swapfile = false
local zenon = require("zenon")
local tests, failures = {}, {}
local api = vim.api

local function eq(expected, actual, message)
  if not vim.deep_equal(expected, actual) then
    error(
      (message or "values differ")
        .. "\nexpected: "
        .. vim.inspect(expected)
        .. "\nactual: "
        .. vim.inspect(actual),
      2
    )
  end
end

local function flush()
  vim.cmd("redraw")
  vim.wait(30)
end

local function editing_buffer(lines)
  local buf = api.nvim_create_buf(true, false)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "writing" })
  vim.bo[buf].modified = false
  return buf
end

local function reset()
  zenon.disable_all()
  vim.cmd("silent! tabonly!")
  vim.cmd("silent! only!")
  api.nvim_win_set_buf(0, editing_buffer())
  vim.o.equalalways = false
  vim.o.ruler = true
  vim.o.showcmd = true
  vim.wo.wrap = false
  vim.wo.number = true
  vim.wo.relativenumber = true
  vim.wo.signcolumn = "yes"
  vim.wo.foldcolumn = "1"
  vim.wo.scrolloff = -1
  vim.wo.showbreak = "original"
  vim.wo.fillchars = "eob:~"
  zenon.setup({ min_width = 1 })
  flush()
end

local function test(name, callback)
  tests[#tests + 1] = { name, callback }
end

local function real_windows()
  return vim.tbl_filter(function(win)
    return not vim.w[win].zenon_padding
  end, api.nvim_tabpage_list_wins(0))
end

local function with_lualine(callback)
  local previous = package.loaded.lualine
  local current = {
    options = {
      theme = "custom",
      disabled_filetypes = { statusline = { "help" }, winbar = { "quickfix" } },
    },
    sections = { lualine_c = { "filename" } },
  }
  local calls = 0
  local lualine = {
    get_config = function()
      return vim.deepcopy(current)
    end,
    setup = function(update)
      calls = calls + 1
      for group, values in pairs(update) do
        for key, value in pairs(values) do
          current[group][key] = vim.deepcopy(value)
        end
      end
    end,
  }
  package.loaded.lualine = lualine
  local ok, failure = xpcall(function()
    callback(lualine, function()
      return calls
    end)
  end, debug.traceback)
  zenon.disable_all()
  package.loaded.lualine = previous
  if not ok then
    error(failure, 0)
  end
end

test("commands enable, resize, and explicitly disable", function()
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  local original_width = api.nvim_win_get_width(win)
  local original_lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.cmd("Zenon")
  eq(math.floor(original_width / 2), api.nvim_win_get_width(win))
  vim.cmd("Zenon")
  eq(true, zenon.is_enabled())
  vim.cmd("Zenon 50 1000 200")
  eq(200, api.nvim_win_get_width(win))
  vim.cmd("Zenoff")
  eq(false, zenon.is_enabled())
  eq(1, #api.nvim_list_wins())
  eq(original_width, api.nvim_win_get_width(win))
  eq(false, vim.wo.wrap)
  eq(true, vim.wo.number)
  eq(true, vim.wo.relativenumber)
  eq("yes", vim.wo.signcolumn)
  eq("1", vim.wo.foldcolumn)
  eq(-1, api.nvim_get_option_value("scrolloff", { win = 0, scope = "local" }))
  eq("original", vim.wo.showbreak)
  eq("eob:~", vim.wo.fillchars)
  eq(true, vim.o.ruler)
  eq(true, vim.o.showcmd)
  eq(original_lines, api.nvim_buf_get_lines(buf, 0, -1, false))
end)

test("width uses the current split and preserves its neighbor", function()
  local host = api.nvim_get_current_win()
  vim.cmd("leftabove vsplit")
  local other = api.nvim_get_current_win()
  api.nvim_win_set_buf(other, editing_buffer())
  api.nvim_win_set_width(other, 59)
  local other_width = api.nvim_win_get_width(other)
  local position = api.nvim_win_get_position(other)
  api.nvim_set_current_win(host)
  local available = api.nvim_win_get_width(host)
  zenon.enable()
  eq(math.floor(available / 2), api.nvim_win_get_width(host))
  eq(other_width, api.nvim_win_get_width(other))
  eq(position, api.nvim_win_get_position(other))
  eq(true, vim.wo[other].number)
  vim.cmd("wincmd h")
  eq(other, api.nvim_get_current_win())
  eq(true, zenon.is_enabled(api.nvim_win_get_buf(host)))
  vim.cmd("wincmd l")
  eq(host, api.nvim_get_current_win())
  api.nvim_exec_autocmds("FocusLost", {})
  eq(true, zenon.is_enabled())
  zenon.disable()
  eq(available, api.nvim_win_get_width(host))
  eq(other_width, api.nvim_win_get_width(other))
end)

test("omitting the maximum allows wide text and a larger minimum", function()
  local available = api.nvim_win_get_width(0)
  zenon.setup({ width = 90 })
  vim.cmd("Zenon")
  eq(math.floor(available * 0.9), api.nvim_win_get_width(0))
  zenon.disable()
  zenon.setup({ width = 1, min_width = 200 })
  zenon.enable()
  eq(200, api.nvim_win_get_width(0))
end)

test("a configured or runtime maximum can be removed", function()
  local available = api.nvim_win_get_width(0)
  local uncapped = math.floor(available * 0.9)
  zenon.setup({ width = 90, min_width = 1, max_width = 100 })
  vim.cmd("Zenon 90")
  eq(100, api.nvim_win_get_width(0))
  zenon.enable({ max_width = false })
  eq(uncapped, api.nvim_win_get_width(0))
  zenon.disable()
  zenon.enable()
  eq(100, api.nvim_win_get_width(0))
  zenon.setup({ width = 90, min_width = 1 })
  eq(uncapped, api.nvim_win_get_width(0))
  zenon.enable({ max_width = 120 })
  eq(120, api.nvim_win_get_width(0))
  zenon.enable({ max_width = false })
  eq(uncapped, api.nvim_win_get_width(0))
end)

test("minimum, maximum, and small available space", function()
  local available = api.nvim_win_get_width(0)
  zenon.enable({ width = 100, min_width = 1, max_width = 100 })
  eq(100, api.nvim_win_get_width(0))
  zenon.enable({ width = 1, min_width = 180, max_width = 1000 })
  eq(180, api.nvim_win_get_width(0))
  zenon.enable({ width = 50, min_width = available + 100, max_width = 1000 })
  eq(available, api.nvim_win_get_width(0))
  eq(1, #api.nvim_list_wins())
  eq(true, zenon.is_enabled())
end)

test("writing options are configurable and scoped to the enabled window", function()
  zenon.setup({ showbreak = false, scrolloff = 4, breakindent = false })
  zenon.enable()
  eq("", vim.wo.showbreak)
  eq(4, vim.wo.scrolloff)
  eq(false, vim.wo.breakindent)
  eq(true, vim.wo.wrap)
  eq(true, vim.wo.linebreak)
  eq(" ", vim.opt_local.fillchars:get().eob)
end)

test("zen follows a buffer through replacement without leaking window options", function()
  local original = api.nvim_get_current_buf()
  local replacement = editing_buffer()
  zenon.enable()
  api.nvim_win_set_buf(0, replacement)
  flush()
  eq(false, zenon.is_enabled())
  eq(true, zenon.is_enabled(original))
  eq(false, vim.wo.wrap)
  eq(true, vim.wo.number)
  eq(1, #api.nvim_list_wins())
  api.nvim_win_set_buf(0, original)
  flush()
  eq(true, vim.wo.wrap)
  eq(true, zenon.is_enabled())
  eq(1, #zenon.status().windows)
end)

test("one enabled buffer can have two independent views", function()
  local buf = api.nvim_get_current_buf()
  zenon.enable()
  vim.cmd("vsplit")
  flush()
  eq(2, #real_windows())
  eq(2, #zenon.status(buf).windows)
  for _, view in ipairs(zenon.status(buf).windows) do
    eq(math.floor(view.available / 2), view.width)
  end
  zenon.disable(buf)
  eq(2, #api.nvim_list_wins())
  for _, win in ipairs(api.nvim_list_wins()) do
    eq(true, vim.wo[win].number, "new splits must restore inherited options")
    eq(false, vim.wo[win].wrap)
  end
end)

test("a sidebar stays usable while zen resizes", function()
  local host, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  zenon.enable()
  vim.cmd("topleft vnew")
  local sidebar = api.nvim_get_current_win()
  vim.bo.buftype = "nofile"
  api.nvim_win_set_width(sidebar, 30)
  flush()
  eq(sidebar, api.nvim_get_current_win())
  eq(true, zenon.is_enabled(buf))
  eq(false, zenon.is_enabled())
  local view = zenon.status(buf).windows[1]
  eq(math.floor(view.available / 2), view.width)
  vim.cmd("wincmd l")
  eq(host, api.nvim_get_current_win())
  api.nvim_set_current_win(sidebar)
  vim.cmd("close")
  flush()
  eq(true, zenon.is_enabled(buf))
  eq(120, api.nvim_win_get_width(host))
end)

test("plain and counted j/k move through visible wrapped rows", function()
  api.nvim_buf_set_lines(0, 0, -1, false, { string.rep("word ", 100), "second", "third", "fourth" })
  zenon.enable({ max_width = 40 })
  api.nvim_win_set_cursor(0, { 1, 0 })
  local first_row = vim.fn.winline()
  vim.cmd("normal j")
  eq(1, api.nvim_win_get_cursor(0)[1])
  eq(first_row + 1, vim.fn.winline())
  assert(api.nvim_win_get_cursor(0)[2] > 0)
  vim.cmd("normal k")
  eq(first_row, vim.fn.winline())
  api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("normal 5j")
  eq(1, api.nvim_win_get_cursor(0)[1])
  eq(first_row + 5, vim.fn.winline())
  vim.cmd("normal 5k")
  eq(1, api.nvim_win_get_cursor(0)[1])
  eq(first_row, vim.fn.winline())
  api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("normal dj")
  eq({ "third", "fourth" }, api.nvim_buf_get_lines(0, 0, -1, false))
end)

test("existing mappings and later user changes survive", function()
  vim.keymap.set("n", "j", "j", { buffer = true, desc = "custom j" })
  zenon.enable()
  eq("custom j", vim.fn.maparg("j", "n", false, true).desc)
  vim.keymap.set("n", "k", "k", { buffer = true, desc = "later k" })
  vim.wo.scrolloff = 3
  zenon.disable()
  eq("custom j", vim.fn.maparg("j", "n", false, true).desc)
  eq("later k", vim.fn.maparg("k", "n", false, true).desc)
  eq(3, vim.wo.scrolloff)
end)

test("global ruler is restored after the last session", function()
  local first = api.nvim_get_current_buf()
  zenon.enable()
  eq(false, vim.o.ruler)
  vim.cmd("new")
  api.nvim_win_set_buf(0, editing_buffer())
  local second = api.nvim_get_current_buf()
  zenon.enable()
  zenon.disable(first)
  eq(false, vim.o.ruler)
  zenon.disable(second)
  eq(true, vim.o.ruler)
  zenon.enable()
  vim.o.ruler = true
  zenon.disable()
  eq(true, vim.o.ruler)
end)

test("invalid input leaves state unchanged and failed initialization rolls back", function()
  for _, values in ipairs({
    { width = 0 },
    { width = 101 },
    { min_width = 0 },
    { min_width = 2000, max_width = 1000 },
    { max_width = 0 },
    { max_width = true },
    { max_width = "100" },
    { scrolloff = -1 },
    { integrations = false },
    { integrations = { lualine = "yes" } },
    { integrations = { [1] = true } },
  }) do
    eq(false, pcall(zenon.enable, values))
    eq(false, zenon.is_enabled())
    eq(1, #api.nvim_list_wins())
  end
  eq(false, pcall(zenon.enable, { window_options = { foldcolumn = "invalid" } }))
  eq(false, zenon.is_enabled())
  eq(1, #api.nvim_list_wins())
  eq(true, vim.wo.number)
  eq(false, vim.wo.wrap)
  eq(true, vim.o.ruler)
end)

test("enable hooks run once and failing hooks leave no partial view", function()
  local enabled, cleaned, disabled = 0, 0, 0
  zenon.setup({
    hooks = {
      on_enable = function(ctx)
        eq(1, #ctx.windows)
        enabled = enabled + 1
        return function()
          cleaned = cleaned + 1
        end
      end,
      on_disable = function()
        disabled = disabled + 1
      end,
    },
  })
  zenon.enable()
  zenon.enable({ width = 60 })
  eq(1, enabled)
  zenon.disable()
  eq(1, cleaned)
  eq(1, disabled)
  zenon.setup({ hooks = {
    on_enable = function()
      error("hook failed")
    end,
  } })
  eq(false, pcall(zenon.enable))
  eq(false, zenon.is_enabled())
  eq(1, #api.nvim_list_wins())
  eq(true, vim.o.ruler)
end)

test("closing a host cleans its margins without disabling another buffer", function()
  vim.cmd("new")
  api.nvim_win_set_buf(0, editing_buffer())
  local buf = api.nvim_get_current_buf()
  zenon.enable()
  vim.cmd("close")
  flush()
  eq(1, #api.nvim_list_wins())
  eq(true, zenon.is_enabled(buf))
  eq(0, #zenon.status(buf).windows)
end)

test("repeated setup and command registration do not duplicate handlers", function()
  local before = #api.nvim_get_autocmds({ group = "Zenon" })
  zenon.setup({})
  zenon.setup({})
  zenon._register()
  eq(before, #api.nvim_get_autocmds({ group = "Zenon" }))
  zenon.enable()
  zenon.setup({ showbreak = "> ", scrolloff = 6 })
  eq(true, zenon.is_enabled())
  eq("> ", vim.wo.showbreak)
  eq(6, vim.wo.scrolloff)
end)

test("default automatic equalization does not resize unrelated windows", function()
  vim.o.equalalways = true
  local host = api.nvim_get_current_win()
  vim.cmd("vsplit")
  local other = api.nvim_get_current_win()
  api.nvim_win_set_buf(other, editing_buffer())
  local width = api.nvim_win_get_width(other)
  api.nvim_set_current_win(host)
  local available = api.nvim_win_get_width(host)
  zenon.enable()
  flush()
  eq(math.floor(available / 2), api.nvim_win_get_width(host))
  eq(width, api.nvim_win_get_width(other))
  eq(true, vim.o.equalalways)
  zenon.disable()
  eq(width, api.nvim_win_get_width(other))
  eq(available, api.nvim_win_get_width(host))
end)

test("failed reconfiguration preserves the active session and its cleanup", function()
  local cleaned = 0
  zenon.setup({
    hooks = {
      on_enable = function()
        return function()
          cleaned = cleaned + 1
        end
      end,
    },
  })
  zenon.enable()
  local width = api.nvim_win_get_width(0)
  eq(false, pcall(zenon.enable, { window_options = { foldcolumn = "invalid" } }))
  eq(true, zenon.is_enabled())
  eq(width, api.nvim_win_get_width(0))
  eq(0, cleaned)
  eq(false, pcall(zenon.setup, { window_options = { foldcolumn = "invalid" } }))
  eq(true, zenon.is_enabled())
  eq(width, api.nvim_win_get_width(0))
  zenon.disable()
  eq(1, cleaned)
end)

test("closing the last editing window never leaves only scratch margins", function()
  zenon.enable()
  vim.cmd("close")
  flush()
  eq(1, #real_windows())
  eq(true, zenon.is_enabled())
  zenon.disable()
  eq(1, #api.nvim_list_wins())
  eq(true, vim.wo.number)
  eq(false, vim.wo.wrap)
  eq(false, vim.wo.winfixbuf)
  eq("", vim.wo.winhighlight)
end)

test("buffer wipe releases the session and global options", function()
  local buf = api.nvim_get_current_buf()
  zenon.enable()
  vim.cmd("enew")
  flush()
  api.nvim_buf_delete(buf, { force = true })
  flush()
  eq(false, zenon.is_enabled(buf))
  eq(true, vim.o.ruler)
  eq(1, #api.nvim_list_wins())
end)

test("cursor, scroll, and undo state survive enable, resize, and disable", function()
  local lines = {}
  for i = 1, 200 do
    lines[i] = "Line " .. i
  end
  api.nvim_buf_set_lines(0, 0, -1, false, lines)
  api.nvim_win_set_cursor(0, { 100, 3 })
  vim.fn.winrestview({ topline = 90, lnum = 100, col = 3 })
  local cursor, view, undo =
    api.nvim_win_get_cursor(0), vim.fn.winsaveview(), vim.fn.undotree().seq_cur
  zenon.enable()
  zenon.enable({ width = 60 })
  zenon.disable()
  eq(cursor, api.nvim_win_get_cursor(0))
  eq(view.topline, vim.fn.winsaveview().topline)
  eq(undo, vim.fn.undotree().seq_cur)
  eq(lines, api.nvim_buf_get_lines(0, 0, -1, false))
end)

test("configuration changes can reveal end-of-buffer markers again", function()
  zenon.enable()
  eq(" ", vim.opt_local.fillchars:get().eob)
  zenon.enable({ hide_eob = false, showbreak = false, wrap_navigation = false })
  eq("~", vim.opt_local.fillchars:get().eob)
  eq("", vim.wo.showbreak)
  eq({}, vim.fn.maparg("j", "n", false, true))
  zenon.disable()
end)

test("unrelated horizontal split heights survive layout transactions", function()
  vim.o.equalalways = true
  local host = api.nvim_get_current_win()
  vim.cmd("belowright new")
  local other = api.nvim_get_current_win()
  api.nvim_win_set_height(other, 10)
  local height = api.nvim_win_get_height(other)
  api.nvim_set_current_win(host)
  zenon.enable()
  eq(height, api.nvim_win_get_height(other))
  zenon.disable()
  eq(height, api.nvim_win_get_height(other))
  eq(false, vim.wo[other].winfixheight)
end)

test("a new unrelated split does not inherit the source writing profile", function()
  local original = api.nvim_get_current_buf()
  zenon.enable()
  vim.cmd("vnew")
  local other = api.nvim_get_current_win()
  vim.wo.scrolloff = 24
  flush()
  eq(false, zenon.is_enabled())
  eq(true, zenon.is_enabled(original))
  eq(false, vim.wo[other].wrap)
  eq(true, vim.wo[other].number)
  eq(24, vim.wo[other].scrolloff)
end)

test("one buffer retains independent zen views across tabs", function()
  local buf = api.nvim_get_current_buf()
  zenon.enable()
  vim.cmd("tab split")
  flush()
  eq(2, #zenon.status(buf).windows)
  vim.cmd("tabprevious")
  flush()
  eq(true, zenon.is_enabled())
  zenon.disable(buf)
  eq(2, #api.nvim_list_wins())
  for _, win in ipairs(api.nvim_list_wins()) do
    eq(true, vim.wo[win].number)
    eq(false, vim.wo[win].wrap)
  end
end)

test("shrinking below the minimum removes margins but retains enabled state", function()
  zenon.enable({ min_width = 80 })
  local width = vim.o.columns
  vim.o.columns = 60
  api.nvim_exec_autocmds("VimResized", {})
  flush()
  local small = {
    enabled = zenon.is_enabled(),
    width = api.nvim_win_get_width(0),
    windows = #api.nvim_list_wins(),
  }
  vim.o.columns = width
  api.nvim_exec_autocmds("VimResized", {})
  flush()
  eq(true, small.enabled)
  eq(60, small.width)
  eq(1, small.windows)
  eq(true, zenon.is_enabled())
  eq(120, api.nvim_win_get_width(0))
end)

test("custom integrations share one lifecycle and receive margin metadata", function()
  local attached, detached, state = 0, 0, {}
  ---@type zenon.IntegrationContext
  local latest = { buffers = {}, windows = {}, margins = {} }
  local unregister = zenon.register_integration("test-bars", {
    attach = function(ctx)
      attached = attached + 1
      eq(1, #ctx.buffers)
      ctx.buffers[1] = -1 -- Each callback receives its own snapshot.
      return state
    end,
    update = function(ctx, saved)
      eq(state, saved)
      latest = ctx
      for _, margin in ipairs(ctx.margins) do
        eq(true, zenon.is_margin(margin.winid))
        eq(true, vim.w[margin.winid].zenon_padding)
        eq("zenon-margin", vim.bo[margin.bufnr].filetype)
        eq("nofile", vim.bo[margin.bufnr].buftype)
        eq(false, vim.bo[margin.bufnr].buflisted)
        eq(false, vim.bo[margin.bufnr].modifiable)
        assert(api.nvim_win_is_valid(margin.owner))
        assert(margin.side == "left" or margin.side == "right")
      end
    end,
    detach = function(ctx, saved)
      eq(state, saved)
      detached = detached + 1
      eq({}, ctx.buffers)
      eq({}, ctx.margins)
    end,
  })
  zenon.setup({ min_width = 1, integrations = { ["test-bars"] = true } })
  local first = api.nvim_get_current_buf()
  zenon.enable()
  eq(false, zenon.is_margin())
  eq(false, zenon.is_margin(-1))
  eq({ first }, latest.buffers)
  eq(1, #latest.windows)
  eq(2, #latest.margins)
  vim.cmd("belowright new")
  local second = api.nvim_get_current_buf()
  zenon.enable()
  eq(1, attached)
  eq(2, #latest.buffers)
  eq(4, #latest.margins)
  zenon.disable(first)
  eq(0, detached)
  zenon.disable(second)
  eq(1, detached)
  unregister()
  unregister()
  eq(1, detached)
end)

test("integrations can register late and unregister while buffers stay enabled", function()
  local ready, attached, detached = false, 0, 0
  zenon.setup({ min_width = 1, integrations = { ["test-late"] = true } })
  zenon.enable()
  local unregister = zenon.register_integration("test-late", {
    available = function()
      return ready
    end,
    attach = function()
      attached = attached + 1
    end,
    detach = function(ctx)
      eq(1, #ctx.buffers)
      detached = detached + 1
    end,
  })
  flush()
  eq(0, attached)
  ready = true
  api.nvim_exec_autocmds("WinEnter", {})
  flush()
  eq(1, attached)
  unregister()
  unregister()
  eq(1, detached)
  eq(true, zenon.is_enabled())
  api.nvim_exec_autocmds("WinEnter", {})
  flush()
  eq(1, attached)
  eq(false, pcall(zenon.register_integration, "invalid", {}))
  eq(false, pcall(zenon.register_integration, "lualine", { attach = function() end }))
end)

test("integration failures clean up once without breaking editing", function()
  local notifications, detached, updates, healthy_updates, healthy_detached = {}, 0, 0, 0, 0
  local previous_notify = vim.notify
  rawset(vim, "notify", function(message)
    notifications[#notifications + 1] = message
  end)
  local unregister = zenon.register_integration("test-failing", {
    attach = function()
      return "saved"
    end,
    update = function()
      updates = updates + 1
      error("update failed")
    end,
    detach = function(_, saved)
      eq("saved", saved)
      detached = detached + 1
      error("cleanup failed")
    end,
  })
  local unregister_healthy = zenon.register_integration("test-healthy", {
    attach = function() end,
    update = function()
      healthy_updates = healthy_updates + 1
    end,
    detach = function()
      healthy_detached = healthy_detached + 1
    end,
  })
  local ok, failure = xpcall(function()
    zenon.setup({
      min_width = 1,
      integrations = { ["test-failing"] = true, ["test-healthy"] = true },
    })
    zenon.enable()
    api.nvim_exec_autocmds("WinEnter", {})
    flush()
    eq(1, updates)
    eq(1, detached)
    eq(2, #notifications)
    assert(healthy_updates > 0)
    eq(true, zenon.is_enabled())
    eq(3, #api.nvim_list_wins())
    zenon.disable()
    eq(1, #api.nvim_list_wins())
    eq(true, vim.o.ruler)
    eq(1, healthy_detached)
  end, debug.traceback)
  unregister()
  unregister_healthy()
  rawset(vim, "notify", previous_notify)
  if not ok then
    error(failure, 0)
  end
end)

test("unavailable and failed adapters do not retry errors on every window event", function()
  local notifications, checks, attaches = {}, 0, 0
  local previous_notify = vim.notify
  rawset(vim, "notify", function(message)
    notifications[#notifications + 1] = message
  end)
  local unregister_check = zenon.register_integration("test-check-error", {
    available = function()
      checks = checks + 1
      error("availability failed")
    end,
    attach = function()
      error("must not be reached")
    end,
  })
  local unregister_attach = zenon.register_integration("test-attach-error", {
    attach = function()
      attaches = attaches + 1
      error("attach failed")
    end,
  })
  local ok, failure = xpcall(function()
    zenon.setup({
      min_width = 1,
      integrations = { ["test-check-error"] = true, ["test-attach-error"] = true },
    })
    zenon.enable()
    api.nvim_exec_autocmds("WinEnter", {})
    flush()
    eq(1, checks)
    eq(1, attaches)
    eq(2, #notifications)
    eq(true, zenon.is_enabled())
    zenon.disable()
    zenon.enable()
    eq(2, checks)
    eq(2, attaches)
  end, debug.traceback)
  zenon.disable_all()
  unregister_check()
  unregister_attach()
  rawset(vim, "notify", previous_notify)
  if not ok then
    error(failure, 0)
  end
end)

test("lualine exclusions preserve configuration and last until the final buffer", function()
  with_lualine(function(lualine, calls)
    local before = lualine.get_config()
    local first = api.nvim_get_current_buf()
    zenon.enable()
    local enabled = lualine.get_config()
    eq({ "help", "zenon-margin" }, enabled.options.disabled_filetypes.statusline)
    eq({ "quickfix", "zenon-margin" }, enabled.options.disabled_filetypes.winbar)
    eq(before.sections, enabled.sections)
    eq(before.options.theme, enabled.options.theme)
    zenon.enable({ width = 60 })
    eq(1, calls())
    vim.cmd("belowright new")
    local second = api.nvim_get_current_buf()
    zenon.enable()
    zenon.disable(first)
    eq(enabled, lualine.get_config())
    zenon.disable(second)
    eq(before, lualine.get_config())
    eq(2, calls())
  end)
end)

test("lualine preserves existing exclusions and later user changes", function()
  with_lualine(function(lualine)
    local before = lualine.get_config()
    before.options.disabled_filetypes.winbar = { "zenon-margin", "help" }
    lualine.setup(before)
    zenon.enable()
    local changed = lualine.get_config()
    changed.options.theme = "later-theme"
    changed.options.disabled_filetypes.statusline = { "custom", "zenon-margin" }
    lualine.setup(changed)
    zenon.disable()
    eq(changed, lualine.get_config())
  end)
end)

test("lualine reconfiguration restores its new baseline after disable", function()
  with_lualine(function(lualine)
    zenon.enable()
    local changed = lualine.get_config()
    changed.options.disabled_filetypes = { statusline = { "new" }, winbar = {} }
    lualine.setup(changed)
    api.nvim_exec_autocmds("WinEnter", {})
    flush()
    eq({ "new", "zenon-margin" }, lualine.get_config().options.disabled_filetypes.statusline)
    zenon.disable()
    eq(changed, lualine.get_config())
  end)
end)

test("lualine stays unloaded and can attach later without leaving margin bars", function()
  with_lualine(function(lualine)
    local previous_preload = package.preload.lualine
    local loads = 0
    package.loaded.lualine = nil
    package.preload.lualine = function()
      loads = loads + 1
      return lualine
    end
    local ok, failure = xpcall(function()
      local host = api.nvim_get_current_win()
      vim.wo[host].winbar = "file title"
      zenon.enable()
      eq(0, loads)
      eq(nil, package.loaded.lualine)
      for _, win in ipairs(api.nvim_list_wins()) do
        if zenon.is_margin(win) then
          vim.wo[win].winbar = "[No Name] [-]"
        end
      end
      package.loaded.lualine = lualine
      api.nvim_exec_autocmds("WinEnter", {})
      flush()
      eq(0, loads)
      eq("file title", vim.wo[host].winbar)
      for _, win in ipairs(api.nvim_list_wins()) do
        if zenon.is_margin(win) then
          eq("", vim.wo[win].winbar)
          eq(" ", vim.wo[win].statusline)
        end
      end
    end, debug.traceback)
    package.preload.lualine = previous_preload
    if not ok then
      error(failure, 0)
    end
  end)
end)

test("lualine integration can be disabled without loading or changing it", function()
  with_lualine(function(lualine, calls)
    local before = lualine.get_config()
    zenon.setup({ min_width = 1, integrations = { lualine = false } })
    zenon.enable()
    eq(0, calls())
    eq(before, lualine.get_config())
    zenon.setup({ min_width = 1 })
    eq(1, calls())
    zenon.setup({ min_width = 1, integrations = { lualine = false } })
    eq(before, lualine.get_config())
    eq(true, zenon.is_enabled())
  end)
end)

test("failed enable restores attached integrations", function()
  with_lualine(function(lualine)
    local before = lualine.get_config()
    zenon.setup({
      hooks = {
        on_enable = function()
          error("initialization failed")
        end,
      },
    })
    eq(false, pcall(zenon.enable))
    eq(false, zenon.is_enabled())
    eq(1, #api.nvim_list_wins())
    eq(before, lualine.get_config())
  end)
end)

for _, entry in ipairs(tests) do
  local ok, failure = xpcall(function()
    reset()
    entry[2]()
    flush()
  end, debug.traceback)
  if ok then
    io.stdout:write("PASS " .. entry[1] .. "\n")
  else
    failures[#failures + 1] = entry[1] .. "\n" .. failure
    print("FAIL " .. entry[1])
  end
end
zenon.disable_all()
if #failures > 0 then
  print(table.concat(failures, "\n\n"))
  vim.cmd("cquit 1")
else
  print(("%d tests passed"):format(#tests))
  vim.cmd("qa!")
end
