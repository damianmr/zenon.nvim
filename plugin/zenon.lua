if vim.g.loaded_zenon then
  return
end
vim.g.loaded_zenon = true
if vim.fn.has("nvim-0.12") == 0 then
  vim.notify("zenon requires Neovim 0.12 or newer", vim.log.levels.ERROR)
  return
end
require("zenon")._register()
