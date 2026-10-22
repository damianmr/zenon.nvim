local layout = require("zenon.layout")
local M = {}
local pending, groups, members = nil, {}, {}

-- WinNewPre permits inspection only. Remember the full host before Neovim
-- divides its narrower text window, then reconcile after native events settle.
function M.before(view, baseline)
  local win = vim.api.nvim_get_current_win()
  local inherited = view or baseline
  pending = {
    win = win,
    view = view,
    available = view and layout.width(view),
    baseline = inherited and {
      buf = vim.api.nvim_win_get_buf(win),
      saved = vim.deepcopy(inherited.saved),
      applied = vim.deepcopy(inherited.applied),
    },
    group = members[win],
    width = vim.api.nvim_win_get_width(win),
    position = vim.api.nvim_win_get_position(win),
    tab = vim.api.nvim_win_get_tabpage(win),
  }
end

function M.after(win)
  local before = pending
  pending = nil
  if not before or before.win == win or not vim.api.nvim_win_is_valid(before.win) then
    return
  end
  local source = before.win
  local view = before.view
  if
    vim.api.nvim_win_get_tabpage(win) == before.tab
    and (before.group or (view and (view.left or view.right)))
  then
    local position = vim.api.nvim_win_get_position(win)
    local old_position = vim.api.nvim_win_get_position(source)
    local width = vim.api.nvim_win_get_width(win)
    local old_width = vim.api.nvim_win_get_width(source)
    local vertical = position[1] == before.position[1]
      and old_position[1] == before.position[1]
      and math.min(position[2], old_position[2]) == before.position[2]
      and old_width + width + 1 == before.width
    local horizontal = position[2] == before.position[2]
      and old_position[2] == before.position[2]
      and position[1] ~= old_position[1]
      and width == before.width
      and old_width == before.width
    if vertical or horizontal then
      local group = before.group
      if not group then
        group = { view = view, targets = { [source] = before.available }, native = {} }
        groups[#groups + 1] = group
      end
      local target = group.targets[source]
      if vertical then
        local extra = target - before.width
        local share = math.floor(extra / 2)
        if old_width < width then
          share = math.ceil(extra / 2)
        end
        group.targets[source] = old_width + share
        group.targets[win] = width + extra - share
      else
        group.targets[win] = target
      end
      group.native[source], group.native[win] = old_width, width
      members[source], members[win] = group, group
    end
  end
  return before.baseline
end

function M.take()
  local result = groups
  pending, groups, members = nil, {}, {}
  return vim.tbl_filter(function(group)
    for win, width in pairs(group.native) do
      -- A sidebar or a later explicit resize owns its geometry. Do not rebalance
      -- it using a snapshot taken before its buffer or size was assigned.
      if
        not layout.real(win)
        or vim.bo[vim.api.nvim_win_get_buf(win)].buftype ~= ""
        or vim.api.nvim_win_get_width(win) ~= width
      then
        return false
      end
    end
    return true
  end, result)
end

return M
