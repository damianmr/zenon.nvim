local options = require("zenon.options")
local M = {}
local filetype = "zenon-margin"

function M.available()
  local api = package.loaded.lualine
  return type(api) == "table"
    and type(api.get_config) == "function"
    and type(api.setup) == "function"
end

local function exclusions(state)
  return vim.deepcopy(state.api.get_config().options.disabled_filetypes)
end

local function apply(state)
  local disabled = exclusions(state)
  local changed = false
  for _, place in ipairs({ "statusline", "winbar" }) do
    local current = disabled[place] or {}
    if not vim.tbl_contains(current, filetype) then
      state.saved[place] = vim.deepcopy(current)
      local added = vim.list_extend(vim.deepcopy(current), { filetype })
      disabled[place], state.applied[place] = added, vim.deepcopy(added)
      changed = true
    end
  end
  if changed then
    state.api.setup({ options = { disabled_filetypes = disabled } })
  end
end

function M.detach(_, state)
  if package.loaded.lualine ~= state.api then
    return
  end
  local disabled = exclusions(state)
  local changed = false
  for place, applied in pairs(state.applied) do
    if vim.deep_equal(disabled[place], applied) then
      disabled[place] = state.saved[place]
      changed = true
    end
  end
  if changed then
    state.api.setup({ options = { disabled_filetypes = disabled } })
  end
end

function M.attach(ctx)
  local state = { api = package.loaded.lualine, saved = {}, applied = {} }
  local ok, message = pcall(apply, state)
  if not ok then
    pcall(M.detach, ctx, state)
    error(message, 0)
  end
  return state
end

function M.update(ctx, state)
  apply(state)
  -- A plugin loaded after zenon.nvim may already have drawn bars in existing margins.
  for _, margin in ipairs(ctx.margins) do
    local win = margin.winid
    if vim.api.nvim_win_is_valid(win) and vim.w[win].zenon_padding then
      for key, value in pairs({ winbar = "", statusline = " " }) do
        if options.get(win, key) ~= value then
          options.set(win, key, value)
        end
      end
    end
  end
end

return M
