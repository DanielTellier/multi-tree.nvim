local M = {}

M.states = {}

function M.create(win, buf, opts)
  local state = {
    win = win,
    buf = buf,
    opts = opts,
    root_node = nil,
    line2node = {},
    prev_cwd = vim.fn.getcwd(),
    sort_mode = "name",
    dir_history = {},
    history_index = 1,
  }
  M.states[buf] = state
  return state
end

function M.get(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  return M.states[buf]
end

function M.get_current()
  return M.get()
end

function M.remove(buf)
  M.states[buf] = nil
end

function M.find_by_path(abs_path)
  local utils = require("multi-tree.utils")
  local current_tab = vim.api.nvim_get_current_tabpage()
  local candidate_any

  for _, st in pairs(M.states) do
    if st.root_node and st.root_node.path and
       vim.api.nvim_win_is_valid(st.win) then
      if utils.normalize_path(st.root_node.path) == abs_path then
        local tab = vim.api.nvim_win_get_tabpage(st.win)
        if tab == current_tab then
          return st
        end
        candidate_any = candidate_any or st
      end
    end
  end
  return candidate_any
end

function M.focus_window(state)
  if not state or not vim.api.nvim_win_is_valid(state.win) then
    return false
  end
  local tab = vim.api.nvim_win_get_tabpage(state.win)
  local nr = vim.api.nvim_tabpage_get_number(tab)
  vim.cmd(("%dtabnext"):format(nr))
  vim.api.nvim_set_current_win(state.win)
  return true
end

return M
