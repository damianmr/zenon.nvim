local M = {}
local registered, active, failed = {}, {}, {}

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

local function report(name, phase, message)
  vim.notify(
    ("zenon: integration '%s' failed to %s: %s"):format(name, phase, tostring(message)),
    vim.log.levels.WARN
  )
end

local function detach(name, ctx)
  local entry = active[name]
  active[name] = nil
  if entry and entry.spec.detach then
    local ok, message = pcall(entry.spec.detach, vim.deepcopy(ctx), entry.state)
    if not ok then
      report(name, "detach", message)
    end
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
  spec = vim.tbl_extend("force", {}, spec)
  registered[name] = spec
  return function(ctx)
    if registered[name] == spec then
      registered[name] = nil
      detach(name, ctx)
      failed[name] = nil
    end
  end
end

function M.reconcile(requested, ctx)
  for _, name in ipairs(vim.tbl_keys(registered)) do
    local spec = registered[name]
    if not requested[name] then
      detach(name, ctx)
      failed[name] = nil
    elseif not failed[name] then
      local ok, available = pcall(function()
        return not spec.available or spec.available()
      end)
      if not ok then
        failed[name] = true
        report(name, "check availability", available)
        detach(name, ctx)
      elseif not available then
        detach(name, ctx)
      elseif not active[name] then
        local attached, state = pcall(spec.attach, vim.deepcopy(ctx))
        if attached then
          active[name] = { spec = spec, state = state }
        else
          failed[name] = true
          report(name, "attach", state)
        end
      end
    end
  end
end

function M.update(ctx)
  for _, name in ipairs(vim.tbl_keys(active)) do
    local entry = active[name]
    if entry.spec.update then
      local ok, message = pcall(entry.spec.update, vim.deepcopy(ctx), entry.state)
      if not ok then
        failed[name] = true
        report(name, "update", message)
        detach(name, ctx)
      end
    end
  end
end

M.register("lualine", require("zenon.integrations.lualine"))

return M
