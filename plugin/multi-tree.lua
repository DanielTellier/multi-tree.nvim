if vim.g.loaded_multi_tree then
  return
end
vim.g.loaded_multi_tree = true

vim.api.nvim_create_user_command("MultiTree", function(opts)
  local path = opts.args ~= "" and opts.args or vim.loop.cwd()
  require("multi-tree").open(path, {})
end, { nargs = "?", complete = "dir" })

vim.api.nvim_create_user_command("MultiTreeRefresh", function()
  require("multi-tree").refresh_current()
end, {})

vim.api.nvim_create_user_command("MultiTreeClose", function()
  require("multi-tree").close_current()
end, {})

vim.api.nvim_create_user_command("MultiTreeTabRename", function(opts)
  require("multi-tree").tab_rename(opts.args)
end, { nargs = 1 })
