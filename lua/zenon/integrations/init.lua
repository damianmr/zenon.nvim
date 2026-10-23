local M = {}
local registered = {}

---@class zenon.IntegrationView
---@field winid integer Editing window ID.
---@field bufnr integer Edited buffer ID.
---@field width integer Text columns.
---@field available integer Available columns in the host region.

---@class zenon.Margin
---@field winid integer Margin window ID.
---@field bufnr integer Scratch buffer ID; two margins may share a buffer.
---@field owner integer Editing window ID.
---@field side "left"|"right"

---@class zenon.IntegrationContext
---@field buffers integer[] Enabled buffer IDs, including hidden buffers.
---@field windows zenon.IntegrationView[] Editing views.
---@field margins zenon.Margin[] Margin windows.

---@class zenon.Integration
---@field available? fun(): boolean Check availability without loading another plugin.
---@field attach fun(ctx: zenon.IntegrationContext): any Prepare integration state.
---@field update? fun(ctx: zenon.IntegrationContext, state: any) Update after layout changes.
---@field detach? fun(ctx: zenon.IntegrationContext, state: any) Restore owned state.

local function call(entry, method, ...)
  local callback = entry.spec[method]
  if not callback then
    return true, true
  end
  local ok, result = pcall(callback, ...)
  if not ok then
    local phase = method == "available" and "check availability" or method
    vim.notify(
      ("zenon: integration '%s' failed to %s: %s"):format(entry.name, phase, tostring(result)),
      vim.log.levels.WARN
    )
  end
  return ok, result
end

local function detach(entry, ctx)
  if entry.active then
    entry.active = false
    call(entry, "detach", vim.deepcopy(ctx), entry.state)
    entry.state = nil
  end
end

function M.register(name, spec)
  if type(name) ~= "string" or name == "" then
    error("zenon: integration name must be a nonempty string", 0)
  end
  if registered[name] then
    error("zenon: integration '" .. name .. "' is already registered", 0)
  end
  if type(spec) ~= "table" or type(spec.attach) ~= "function" then
    error("zenon: integration '" .. name .. "' requires an attach function", 0)
  end
  for key, value in pairs(spec) do
    if not vim.tbl_contains({ "available", "attach", "update", "detach" }, key) then
      error("zenon: unknown integration callback '" .. tostring(key) .. "'", 0)
    end
    if type(value) ~= "function" then
      error("zenon: integration callback '" .. key .. "' must be a function", 0)
    end
  end
  local entry = { name = name, spec = vim.tbl_extend("force", {}, spec) }
  registered[name] = entry
  return function(ctx)
    if registered[name] == entry then
      registered[name] = nil
      detach(entry, ctx)
    end
  end
end

function M.reconcile(requested, ctx)
  for name, entry in pairs(registered) do
    if not requested[name] then
      detach(entry, ctx)
      entry.failed = nil
    elseif not entry.failed then
      local ok, available = call(entry, "available")
      if not ok then
        entry.failed = true
        detach(entry, ctx)
      elseif not available then
        detach(entry, ctx)
      elseif not entry.active then
        local attached, state = call(entry, "attach", vim.deepcopy(ctx))
        if attached then
          entry.active, entry.state = true, state
        else
          entry.failed = true
        end
      end
    end
  end
end

function M.update(ctx)
  for _, entry in pairs(registered) do
    if entry.active and entry.spec.update then
      local ok = call(entry, "update", vim.deepcopy(ctx), entry.state)
      if not ok then
        entry.failed = true
        detach(entry, ctx)
      end
    end
  end
end

M.register("lualine", require("zenon.integrations.lualine"))

return M
