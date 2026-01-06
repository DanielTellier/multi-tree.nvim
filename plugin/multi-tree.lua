if vim.g.loaded_multi_tree then
  return
end
vim.g.loaded_multi_tree = true

vim.api.nvim_create_user_command("MultiTree", function(opts)
  local args = vim.split(opts.args, "%s+")
  local open_type = args[1] or "vnew"
  local path = args[2] or vim.loop.cwd()
  require("multi-tree").open(open_type, path)
end, { nargs = "*", complete = "dir" })

vim.api.nvim_create_user_command("MultiTreeRefresh", function()
  require("multi-tree").refresh_current()
end, {})

vim.api.nvim_create_user_command("MultiTreeClose", function()
  require("multi-tree").close_current()
end, {})
