local M = {}

---@class zenon.Options
---@field width? number Percentage of the host split, in (0, 100].
---@field min_width? integer Minimum text columns, limited by available space.
---@field max_width? integer Maximum text columns.
---@field showbreak? string|false Marker on wrapped continuation rows.
---@field scrolloff? integer Screen rows of scrolling context.
---@field breakindent? boolean Indent wrapped continuation rows.
---@field wrap? boolean
---@field linebreak? boolean
---@field wrap_navigation? boolean Move normal-mode j/k by visible rows, including counts.
---@field hide_eob? boolean Hide end-of-buffer markers.
---@field dim? number|false Amount to darken the empty margins, from 0 to 1.
---@field ruler? boolean Global ruler value while any buffer is enabled.
---@field window_options? table<string, boolean|number|string>
---@field hooks? table<string, function>
M.defaults = {
  width = 50,
  min_width = 80,
  max_width = 160,
  showbreak = "↪",
  scrolloff = 10,
  breakindent = true,
  wrap = true,
  linebreak = true,
  wrap_navigation = true,
  hide_eob = true,
  dim = 0.15,
  ruler = false,
  window_options = {
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    list = false,
    cursorline = false,
    cursorcolumn = false,
  },
  hooks = {},
}

local function finite(value)
  return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function integer(value, minimum)
  return finite(value) and value % 1 == 0 and value >= minimum
end

local function check(ok, message)
  if not ok then
    error("zenon: " .. message, 0)
  end
end

function M.validate(options)
  for key in pairs(options) do
    check(M.defaults[key] ~= nil, "unknown option '" .. tostring(key) .. "'")
  end
  check(
    finite(options.width) and options.width > 0 and options.width <= 100,
    "width must be a percentage in (0, 100]"
  )
  check(integer(options.min_width, 1), "min_width must be a positive integer")
  check(integer(options.max_width, 1), "max_width must be a positive integer")
  check(options.min_width <= options.max_width, "min_width must not exceed max_width")
  check(integer(options.scrolloff, 0), "scrolloff must be a nonnegative integer")
  check(
    options.showbreak == false or type(options.showbreak) == "string",
    "showbreak must be false or a string"
  )
  if type(options.showbreak) == "string" then
    check(not options.showbreak:find("[\r\n]"), "showbreak must not contain a newline")
  end
  check(
    options.dim == false or (finite(options.dim) and options.dim >= 0 and options.dim <= 1),
    "dim must be false or a number from 0 to 1"
  )
  for _, key in ipairs({
    "breakindent",
    "wrap",
    "linebreak",
    "wrap_navigation",
    "hide_eob",
    "ruler",
  }) do
    check(type(options[key]) == "boolean", key .. " must be a boolean")
  end
  check(type(options.window_options) == "table", "window_options must be a table")
  for key, value in pairs(options.window_options) do
    local ok, info = pcall(vim.api.nvim_get_option_info2, key, {})
    check(
      ok and info.scope == "win",
      "window_options.'" .. tostring(key) .. "' must be a window-local option"
    )
    check(type(value) == info.type, "invalid value type for window_options.'" .. key .. "'")
  end
  check(type(options.hooks) == "table", "hooks must be a table")
  for key, value in pairs(options.hooks) do
    check(
      vim.tbl_contains({ "on_enable", "on_disable", "on_resize" }, key),
      "unknown hook '" .. tostring(key) .. "'"
    )
    check(type(value) == "function", "hook '" .. key .. "' must be a function")
  end
  return options
end

function M.merge(base, overrides)
  check(overrides == nil or type(overrides) == "table", "options must be a table")
  return M.validate(vim.tbl_deep_extend("force", {}, base, overrides or {}))
end

function M.command(arguments)
  check(#arguments <= 3, "usage: Zenon [percentage [maximum [minimum]]]")
  local result = {}
  for index, key in ipairs({ "width", "max_width", "min_width" }) do
    if arguments[index] then
      result[key] = tonumber(arguments[index])
      check(result[key] ~= nil, key .. " must be a number")
    end
  end
  return result
end

function M.columns(available, options)
  local desired = math.floor(available * options.width / 100)
  return math.max(1, math.min(available, options.max_width, math.max(options.min_width, desired)))
end

return M
