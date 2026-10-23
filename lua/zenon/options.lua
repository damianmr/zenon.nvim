local M = {}

function M.get(win, key)
  return vim.api.nvim_get_option_value(key, { win = win, scope = "local" })
end

function M.set(win, key, value)
  vim.api.nvim_set_option_value(key, value, { win = win, scope = "local" })
end

function M.baseline(win, pending)
  local saved = {}
  for key, value in pairs(pending.saved) do
    local current = M.get(win, key)
    if pending.applied[key] ~= nil and current ~= pending.applied[key] then
      saved[key] = current
    else
      saved[key] = value
    end
  end
  return saved
end

function M.apply(view, options)
  view.saved = view.saved or {}
  view.applied = view.applied or {}
  view.requested = view.requested or {}
  local values = vim.tbl_extend("force", {
    wrap = options.wrap,
    linebreak = options.linebreak,
    breakindent = options.breakindent,
    showbreak = options.showbreak or "",
    scrolloff = options.scrolloff,
  }, options.window_options)
  local fillchars = values.fillchars
  values.fillchars = nil
  for key, value in pairs(values) do
    local current = M.get(view.win, key)
    if
      view.saved[key] == nil
      or (view.requested[key] ~= nil and (view.applied[key] == nil or current ~= view.applied[key]))
    then
      view.saved[key] = current
      view.applied[key] = nil
    end
    if view.requested[key] ~= value then
      M.set(view.win, key, value)
      view.applied[key] = M.get(view.win, key)
    end
    view.requested[key] = value
  end
  local profile = tostring(options.hide_eob) .. "\0" .. (fillchars or "")
  local current = M.get(view.win, "fillchars")
  local applied = view.applied.fillchars
  if applied ~= nil and current ~= applied then
    view.saved.fillchars = current
    view.applied.fillchars = nil
  elseif applied == nil and view.saved.fillchars ~= nil and view.fillchars_request ~= nil then
    view.saved.fillchars = current
  end
  if options.hide_eob or fillchars ~= nil then
    if view.fillchars_request ~= profile then
      view.saved.fillchars = view.saved.fillchars or current
      if fillchars ~= nil then
        M.set(view.win, "fillchars", fillchars)
      end
      if options.hide_eob then
        vim.api.nvim_win_call(view.win, function()
          vim.opt_local.fillchars:append({ eob = " " })
        end)
      end
      view.applied.fillchars = M.get(view.win, "fillchars")
    end
  elseif view.fillchars_request ~= nil then
    if applied ~= nil and current == applied then
      M.set(view.win, "fillchars", view.saved.fillchars)
    end
    view.saved.fillchars, view.applied.fillchars = nil, nil
  end
  view.fillchars_request = profile
end

function M.restore(view)
  if not vim.api.nvim_win_is_valid(view.win) then
    return
  end
  for key, value in pairs(view.saved or {}) do
    if M.get(view.win, key) == view.applied[key] then
      pcall(M.set, view.win, key, value)
    end
  end
end

local function local_map(buf, key)
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if
      mapping.lhs == key
      or vim.api.nvim_replace_termcodes(mapping.lhs, true, true, true)
        == vim.api.nvim_replace_termcodes(key, true, true, true)
    then
      return mapping
    end
  end
end

function M.map(session, key, callback, description, expression)
  if local_map(session.buf, key) then
    return
  end
  vim.keymap.set("n", key, callback, {
    buffer = session.buf,
    expr = expression or false,
    silent = true,
    desc = "zenon.nvim: " .. description,
  })
  session.maps[key] = callback
end

function M.clear_maps(session)
  if vim.api.nvim_buf_is_valid(session.buf) then
    for key, callback in pairs(session.maps) do
      local current = local_map(session.buf, key)
      if current and current.callback == callback then
        vim.keymap.del("n", key, { buffer = session.buf })
      end
    end
  end
  session.maps = {}
end

function M.navigation(session)
  if session.options.wrap_navigation then
    for _, key in ipairs({ "j", "k" }) do
      M.map(session, key, function()
        return vim.wo.wrap and ("g" .. key) or key
      end, "move " .. (key == "j" and "down" or "up") .. " through wrapped rows", true)
    end
  end
end

return M
