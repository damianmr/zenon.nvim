local config = require("zenon.config")
local layout = require("zenon.layout")
local splits = require("zenon.splits")
local options = require("zenon.options")
local integrations = require("zenon.integrations")
local M = {}
local settings = vim.deepcopy(config.defaults)
local buffers, views, baselines = {}, {}, {}
local busy, queued, exiting = false, false, false
local ruler
local synchronize

local function buffer_number(buf)
  return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
end

local function window_context(buf)
  local result = {}
  for win, view in pairs(views) do
    if (not buf or view.buf == buf) and vim.api.nvim_win_is_valid(win) then
      result[#result + 1] = {
        winid = win,
        bufnr = not buf and view.buf or nil,
        width = view.width,
        available = view.available,
      }
    end
  end
  table.sort(result, function(a, b)
    return a.winid < b.winid
  end)
  return result
end

local function integration_context()
  local ctx = { buffers = vim.tbl_keys(buffers), windows = window_context(), margins = {} }
  for win, margin in pairs(layout.padding) do
    if vim.api.nvim_win_is_valid(win) then
      ctx.margins[#ctx.margins + 1] = {
        winid = win,
        bufnr = vim.api.nvim_win_get_buf(win),
        owner = margin.owner,
        side = margin.side,
      }
    end
  end
  table.sort(ctx.buffers)
  table.sort(ctx.margins, function(a, b)
    return a.winid < b.winid
  end)
  return ctx
end

local function notify(message)
  vim.notify("zenon: " .. tostring(message), vim.log.levels.ERROR)
end

local function global_options()
  local requested = {}
  if next(buffers) then
    local value = true
    for _, session in pairs(buffers) do
      value = value and session.options.ruler
      for name, enabled in pairs(session.options.integrations) do
        requested[name] = requested[name] or enabled
      end
    end
    if not ruler then
      ruler = { saved = vim.o.ruler, applied = value }
      vim.o.ruler = value
    elseif ruler.applied ~= value then
      vim.o.ruler = value
      ruler.applied = value
    end
  elseif ruler then
    if vim.o.ruler == ruler.applied then
      vim.o.ruler = ruler.saved
    end
    ruler = nil
  end
  integrations.reconcile(requested, integration_context())
end

local function context(buf, reason)
  return {
    bufnr = buf,
    reason = reason,
    session_count = vim.tbl_count(buffers),
    windows = window_context(buf),
  }
end

local function hook(session, name, reason, strict)
  local callback = session.options.hooks[name]
  if callback then
    local ok, value = xpcall(function()
      return callback(context(session.buf, reason))
    end, debug.traceback)
    if not ok then
      if strict then
        error(value, 0)
      end
      notify(value)
    else
      return value
    end
  end
end

local function locked(callback)
  if busy then
    error("zenon: a lifecycle operation is already running", 0)
  end
  busy = true
  local ok, result = xpcall(callback, debug.traceback)
  busy = false
  if not ok then
    error(result, 0)
  end
  return result
end

local function schedule()
  if queued or exiting then
    return
  end
  queued = true
  vim.schedule(function()
    queued = false
    if exiting then
      return
    end
    if busy then
      schedule()
      return
    end
    local ok, failure = pcall(locked, synchronize)
    if not ok then
      notify(failure)
    end
  end)
end

local function remove_view(win)
  local view = views[win]
  if not view then
    return
  end
  local replacement = layout.recover(view)
  if replacement then
    baselines[replacement] = { saved = view.saved, applied = {} }
  end
  views[win] = nil
  layout.destroy(view)
end

local function remove_views(buf)
  for _, win in ipairs(vim.tbl_keys(views)) do
    if not buf or views[win].buf == buf then
      remove_view(win)
    end
  end
end

local function repair_splits()
  for _, group in ipairs(splits.take()) do
    if views[group.view.win] == group.view then
      remove_view(group.view.win)
      layout.redistribute(group.targets)
    end
  end
end

local function remove_buffer(buf, reason)
  local session = buffers[buf]
  if not session then
    return
  end
  repair_splits()
  remove_views(buf)
  options.clear_maps(session)
  buffers[buf] = nil
  global_options()
  if session.cleanup then
    local ok, failure = pcall(session.cleanup, context(buf, reason))
    if not ok then
      notify(failure)
    end
  end
  hook(session, "on_disable", reason)
end

synchronize = function()
  repair_splits()
  for _, buf in ipairs(vim.tbl_keys(buffers)) do
    if not vim.api.nvim_buf_is_valid(buf) then
      remove_buffer(buf, "wipe")
    end
  end
  global_options()
  for _, win in ipairs(vim.tbl_keys(views)) do
    local view = views[win]
    if
      not vim.api.nvim_win_is_valid(win)
      or not buffers[view.buf]
      or vim.api.nvim_win_get_buf(win) ~= view.buf
      or not layout.contiguous(view)
    then
      remove_view(win)
    end
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if layout.real(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local session = buffers[buf]
      local pending = baselines[win]
      local baseline
      if pending then
        if session then
          baseline = options.baseline(win, pending)
        else
          options.restore({ win = win, saved = pending.saved, applied = pending.applied })
        end
        baselines[win] = nil
      end
      if session then
        if not views[win] then
          views[win] = layout.create(win, session.options, baseline)
          hook(session, "on_resize", "window_open")
        elseif layout.resize(views[win], session.options) then
          hook(session, "on_resize", "resize")
        end
      end
    end
  end
  integrations.update(integration_context())
end

local function install_maps(session)
  options.clear_maps(session)
  options.navigation(session)
  layout.navigation(session)
end

local function configure(candidate, merged)
  remove_views()
  settings = candidate
  for buf, session in pairs(buffers) do
    session.options = merged[buf]
    install_maps(session)
  end
  synchronize()
end

---@param opts? zenon.Options
function M.setup(opts)
  local candidate = config.merge(config.defaults, opts)
  locked(function()
    repair_splits()
    local previous = settings
    local merged, previous_options = {}, {}
    for buf, session in pairs(buffers) do
      merged[buf] = config.merge(candidate, session.overrides)
      previous_options[buf] = session.options
    end
    local ok, failure = pcall(configure, candidate, merged)
    if not ok then
      configure(previous, previous_options)
      error(failure, 0)
    end
  end)
end

---@param opts? zenon.Options
---@param buf? integer Defaults to the current buffer.
function M.enable(opts, buf)
  buf = buffer_number(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
    error("zenon: enable a normal editing buffer", 0)
  end
  local existing = buffers[buf]
  local candidate = config.merge(existing and existing.options or settings, opts)
  local overrides =
    vim.tbl_deep_extend("force", {}, existing and existing.overrides or {}, opts or {})
  return locked(function()
    local session = existing or { buf = buf, maps = {} }
    local previous_options, previous_overrides = session.options, session.overrides
    session.options, session.overrides = candidate, overrides
    buffers[buf] = session
    local ok, failure = xpcall(function()
      install_maps(session)
      for _, view in pairs(views) do
        if view.buf == buf then
          options.apply(view, candidate)
          layout.colors(view, candidate.dim)
        end
      end
      synchronize()
      if not existing then
        local cleanup = hook(session, "on_enable", "enable", true)
        if cleanup ~= nil and type(cleanup) ~= "function" then
          error("zenon: on_enable must return a cleanup function or nil", 0)
        end
        session.cleanup = cleanup
      end
    end, debug.traceback)
    if not ok then
      if existing then
        remove_views(buf)
        session.options, session.overrides = previous_options, previous_overrides
        install_maps(session)
        synchronize()
      else
        remove_buffer(buf, "error")
      end
      error(failure, 0)
    end
    return context(buf, existing and "resize" or "enable")
  end)
end

---@param buf? integer
function M.disable(buf)
  buf = buffer_number(buf)
  return locked(function()
    remove_buffer(buf, "disable")
    synchronize()
  end)
end

function M.disable_all()
  return locked(function()
    for _, buf in ipairs(vim.tbl_keys(buffers)) do
      remove_buffer(buf, "disable")
    end
    synchronize()
  end)
end

---@param buf? integer
function M.is_enabled(buf)
  return buffers[buffer_number(buf)] ~= nil
end

---@param win? integer Defaults to the current window.
function M.is_margin(win)
  if win == nil or win == 0 then
    win = vim.api.nvim_get_current_win()
  end
  return vim.api.nvim_win_is_valid(win) and layout.padding[win] ~= nil
end

---@param name string
---@param spec zenon.Integration
---@return function unregister
function M.register_integration(name, spec)
  local unregister = locked(function()
    return integrations.register(name, spec)
  end)
  schedule()
  return function()
    locked(function()
      unregister(integration_context())
    end)
  end
end

---@param buf? integer
function M.status(buf)
  buf = buffer_number(buf)
  local result = context(buf, "status")
  result.enabled = buffers[buf] ~= nil
  return result
end

local function command(callback)
  return function(args)
    local ok, failure = pcall(callback, args)
    if not ok then
      notify(failure)
    end
  end
end

local function register()
  vim.api.nvim_create_user_command(
    "Zenon",
    command(function(args)
      M.enable(config.command(args.fargs))
    end),
    { nargs = "*", desc = "Enable or resize zenon: [percentage [maximum [minimum]]]" }
  )
  vim.api.nvim_create_user_command(
    "Zenoff",
    command(function(args)
      if args.bang then
        M.disable_all()
      else
        M.disable()
      end
    end),
    { bang = true, desc = "Disable zenon for this buffer; ! disables every buffer" }
  )
  local group = vim.api.nvim_create_augroup("Zenon", { clear = true })
  local function on(events, callback, nested)
    vim.api.nvim_create_autocmd(events, { group = group, callback = callback, nested = nested })
  end
  on("WinEnter", function()
    layout.enter()
    schedule()
  end, true)
  on("WinNewPre", function()
    local win = vim.api.nvim_get_current_win()
    splits.before(views[win], baselines[win])
  end)
  on("WinNew", function()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    local inherited = splits.after(win)
    if buffers[buf] then
      local source = inherited or views[vim.fn.win_getid(vim.fn.winnr("#"))]
      if not source and layout.last then
        source = views[layout.last]
      end
      if source and source.buf == buf then
        baselines[win] = {
          saved = vim.deepcopy(source.saved),
          applied = vim.deepcopy(source.applied),
        }
      end
    end
    schedule()
  end)
  on({ "BufWinEnter", "VimResized", "WinResized", "TabEnter" }, schedule)
  on("WinClosed", function(event)
    local win = tonumber(event.match)
    if win then
      layout.padding[win] = nil
      baselines[win] = nil
    end
    schedule()
  end)
  on("BufWipeout", function(event)
    if buffers[event.buf] then
      if busy then
        schedule()
      else
        locked(function()
          remove_buffer(event.buf, "wipe")
        end)
      end
    end
  end)
  on("QuitPre", function()
    local win = vim.api.nvim_get_current_win()
    if views[win] and not busy then
      locked(function()
        remove_view(win)
      end)
      schedule()
    end
  end)
  on("ColorScheme", function()
    for _, view in pairs(views) do
      layout.colors(view, buffers[view.buf].options.dim)
    end
  end)
  on("VimLeavePre", function()
    exiting = true
    if not busy then
      M.disable_all()
    end
  end)
  layout.enter()
end

register()
return M
