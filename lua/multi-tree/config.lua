local M = {}

M.defaults = {
  show_hidden = false,
  icons = true,
  indent = 2,
  map_next_tab_keys = true,
  set_local_cwd = true,
  restore_local_cwd_on_close = false,
  hijack_netrw = false,
}

M.values = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.values = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

function M.get()
  return M.values
end

return M
