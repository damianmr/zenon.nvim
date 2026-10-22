local M = {}

function M.check()
  vim.health.start("zenon")
  if vim.fn.has("nvim-0.12") == 1 then
    vim.health.ok("Neovim 0.12 or newer")
  else
    vim.health.error("Neovim 0.12 or newer is required")
  end
  vim.health.ok("No external programs or runtime plugins required")
  local state = require("zenon").status()
  vim.health.info(
    state.enabled and ("Current buffer enabled in " .. #state.windows .. " window(s)")
      or "Current buffer disabled"
  )
  vim.health.info("ruler is global; other editing options are scoped to enabled views")
end

return M
