if vim.g.loaded_multi_tree then
  return
end
vim.g.loaded_multi_tree = true

vim.api.nvim_create_user_command("MultiTree", function(opts)
  local open_type = opts.fargs[1]
  local path = opts.fargs[2]
  require("multi-tree").open(path, open_type)
end, { nargs = 2, complete = "dir" })

vim.api.nvim_create_user_command("MultiTreeRefresh", function()
  require("multi-tree").refresh_current()
end, {})

vim.api.nvim_create_user_command("MultiTreeClose", function()
  require("multi-tree").close_current()
end, {})
