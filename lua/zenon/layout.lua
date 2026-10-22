local config = require("zenon.config")
local options = require("zenon.options")
local M = { padding = {}, last = nil }

local function valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

function M.real(win)
  return valid(win) and not M.padding[win] and vim.api.nvim_win_get_config(win).relative == ""
end

-- Layout changes must not make Neovim equalize unrelated splits.
local function transaction(callback, owner)
  local equalalways = vim.o.equalalways
  local fixed, fixed_height = {}, {}
  vim.o.equalalways = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      fixed[win] = options.get(win, "winfixwidth")
      fixed_height[win] = options.get(win, "winfixheight")
      local margin = M.padding[win]
      options.set(win, "winfixwidth", win ~= owner and not (margin and margin.owner == owner))
    end
  end
  local ok, result = xpcall(callback, debug.traceback)
  local normal = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      normal[#normal + 1] = win
      options.set(win, "winfixwidth", true)
      options.set(win, "winfixheight", true)
    end
  end
  vim.o.equalalways = equalalways
  for _, win in ipairs(normal) do
    options.set(win, "winfixwidth", fixed[win] or false)
    options.set(win, "winfixheight", fixed_height[win] or false)
  end
  if not ok then
    error(result, 0)
  end
  return result
end

function M.colors(view, amount)
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local hl = {}
  if normal.bg then
    local value = 0
    for _, shift in ipairs({ 16, 8, 0 }) do
      local channel = math.floor(normal.bg / 2 ^ shift) % 256
      value = value + math.floor(channel * (1 - (amount or 0))) * 2 ^ shift
    end
    hl.bg = value
    hl.fg = value
  end
  vim.api.nvim_set_hl(0, view.highlight, hl)
end

local function pad(view, side, width)
  local win = vim.api.nvim_open_win(view.pad_buf, false, {
    split = side,
    win = view.win,
    width = width,
    noautocmd = true,
  })
  M.padding[win] = { owner = view.win, side = side }
  view[side] = win
  vim.w[win].zenon_padding = true
  local values = {
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    statuscolumn = "",
    cursorline = false,
    cursorcolumn = false,
    list = false,
    spell = false,
    wrap = false,
    winbar = "",
    statusline = " ",
    winfixbuf = true,
    fillchars = "eob: ,vert: ,horiz: ,horizup: ,horizdown: ,vertleft: ,vertright: ,verthoriz: ",
    winhighlight = ("Normal:%s,NormalNC:%s,EndOfBuffer:%s,WinSeparator:%s,StatusLine:%s,StatusLineNC:%s"):format(
      view.highlight,
      view.highlight,
      view.highlight,
      view.highlight,
      view.highlight,
      view.highlight
    ),
  }
  for key, value in pairs(values) do
    options.set(win, key, value)
  end
end

local function close_pad(view, side)
  local win = view[side]
  if not win then
    return
  end
  view[side] = nil
  if valid(win) then
    vim.api.nvim_win_call(win, function()
      vim.cmd("noautocmd close!")
    end)
  end
  M.padding[win] = nil
end

function M.width(view)
  if not valid(view.win) then
    return 0
  end
  local total = vim.api.nvim_win_get_width(view.win)
  for _, side in ipairs({ "left", "right" }) do
    if valid(view[side]) then
      total = total + vim.api.nvim_win_get_width(view[side]) + 1
    end
  end
  return total
end

local function gutters(win)
  local info = vim.fn.getwininfo(win)[1]
  return info and info.textoff or 0
end

function M.resize(view, opts)
  if not valid(view.win) then
    return
  end
  return transaction(function()
    local available = M.width(view)
    local textoff = gutters(view.win)
    local target = config.columns(math.max(1, available - textoff), opts)
    local spare = available - textoff - target
    local left, right = 0, 0
    if spare >= 4 then
      left = math.floor((spare - 2) / 2)
      right = spare - 2 - left
    elseif spare > 0 then
      right = math.max(1, spare - 1)
    end
    if left == 0 then
      close_pad(view, "left")
    end
    if right == 0 then
      close_pad(view, "right")
    end
    if left > 0 and not valid(view.left) then
      pad(view, "left", 1)
    end
    if right > 0 and not valid(view.right) then
      pad(view, "right", 1)
    end
    local left_width = valid(view.left) and vim.api.nvim_win_get_width(view.left) or 0
    local right_width = valid(view.right) and vim.api.nvim_win_get_width(view.right) or 0
    if left_width ~= left or right_width ~= right then
      -- Give the text room before growing either margin.
      if valid(view.left) then
        vim.api.nvim_win_set_width(view.left, 1)
      end
      if valid(view.right) then
        vim.api.nvim_win_set_width(view.right, 1)
      end
      if left > 0 then
        vim.api.nvim_win_set_width(view.left, left)
      end
      if right > 0 then
        vim.api.nvim_win_set_width(view.right, right)
      end
    end
    local width = vim.api.nvim_win_get_width(view.win) - gutters(view.win)
    local changed = width ~= view.width or available ~= view.available
    view.width, view.available = width, available
    return changed
  end, view.win)
end

function M.create(win, opts, baseline)
  local view = {
    win = win,
    buf = vim.api.nvim_win_get_buf(win),
    saved = baseline,
    highlight = "ZenonMargin" .. win,
  }
  view.recovery = {}
  for _, key in ipairs({
    "number",
    "relativenumber",
    "signcolumn",
    "foldcolumn",
    "statuscolumn",
    "cursorline",
    "cursorcolumn",
    "list",
    "spell",
    "wrap",
    "winbar",
    "statusline",
    "winfixbuf",
    "fillchars",
    "winhighlight",
  }) do
    view.recovery[key] = options.get(win, key)
  end
  local ok, failure = xpcall(function()
    view.pad_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[view.pad_buf].bufhidden = "hide"
    vim.bo[view.pad_buf].swapfile = false
    vim.bo[view.pad_buf].modifiable = false
    vim.bo[view.pad_buf].filetype = "zenon-margin"
    M.colors(view, opts.dim)
    options.apply(view, opts)
    M.resize(view, opts)
  end, debug.traceback)
  if not ok then
    M.destroy(view)
    error(failure, 0)
  end
  return view
end

function M.recover(view, win)
  for key, value in pairs(view.recovery) do
    options.set(win, key, value)
  end
  vim.w[win].zenon_padding = nil
end

function M.destroy(view)
  transaction(function()
    close_pad(view, "right")
    close_pad(view, "left")
    options.restore(view)
    if view.highlight then
      vim.api.nvim_set_hl(0, view.highlight, {})
    end
    if view.pad_buf and vim.api.nvim_buf_is_valid(view.pad_buf) then
      vim.api.nvim_buf_delete(view.pad_buf, { force = true })
    end
  end, view.win)
end

function M.contiguous(view)
  if not valid(view.win) then
    return false
  end
  local position = vim.api.nvim_win_get_position(view.win)
  local height = vim.api.nvim_win_get_height(view.win)
  for _, side in ipairs({ "left", "right" }) do
    local win = view[side]
    if valid(win) then
      local other = vim.api.nvim_win_get_position(win)
      if other[1] ~= position[1] or vim.api.nvim_win_get_height(win) ~= height then
        return false
      end
      if side == "left" and other[2] + vim.api.nvim_win_get_width(win) + 1 ~= position[2] then
        return false
      end
      if side == "right" and position[2] + vim.api.nvim_win_get_width(view.win) + 1 ~= other[2] then
        return false
      end
    end
  end
  return true
end

-- Native margins remain ordinary split windows. Skip them synchronously so
-- directional navigation, including external navigator plugins, sees real windows.
function M.enter()
  local current = vim.api.nvim_get_current_win()
  local margin = M.padding[current]
  if not margin then
    if M.real(current) and current ~= M.last then
      M.last = current
    end
    return
  end
  if not valid(margin.owner) then
    return
  end
  local target = margin.owner
  if M.last == margin.owner then
    local direction = margin.side == "left" and "h" or "l"
    local candidate = vim.fn.win_getid(vim.fn.winnr(direction))
    local seen = {}
    while M.padding[candidate] and not seen[candidate] do
      seen[candidate] = true
      candidate = vim.api.nvim_win_call(candidate, function()
        return vim.fn.win_getid(vim.fn.winnr(direction))
      end)
    end
    if M.real(candidate) then
      target = candidate
    end
  end
  vim.api.nvim_set_current_win(target)
end

function M.cycle(step)
  local wins = vim.tbl_filter(M.real, vim.api.nvim_tabpage_list_wins(0))
  local current = vim.api.nvim_get_current_win()
  for index, win in ipairs(wins) do
    if win == current then
      vim.api.nvim_set_current_win(wins[(index - 1 + step * vim.v.count1) % #wins + 1])
      return
    end
  end
end

function M.navigation(session)
  for key, step in pairs({ ["<C-w>w"] = 1, ["<C-w><C-w>"] = 1, ["<C-w>W"] = -1 }) do
    options.map(session, key, function()
      M.cycle(step)
    end, "cycle through editing windows")
  end
end

return M
