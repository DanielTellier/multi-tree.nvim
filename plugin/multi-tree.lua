if vim.g.loaded_multi_tree then
  return
end
vim.g.loaded_multi_tree = true

local function set_default_highlights()
  local hl = vim.api.nvim_set_hl
  hl(0, "MultiTreeRoot",   { default = true, link = "Title" })
  hl(0, "MultiTreeDir",    { default = true, link = "Directory" })
  hl(0, "MultiTreeFile",   { default = true, link = "Normal" })
  hl(0, "MultiTreeHidden", { default = true, link = "Comment" })
  hl(0, "MultiTreeMarker", { default = true, link = "Special" })
  hl(0, "MultiTreeIcon",   { default = true, link = "Special" })
end
set_default_highlights()

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("multi_tree_hl", { clear = true }),
  callback = set_default_highlights,
})

require("multi-tree.file_explorer").setup()

vim.api.nvim_create_user_command("MultiTree", function(opts)
  local path = opts.args ~= "" and opts.args or vim.loop.cwd()
  require("multi-tree").open(path)
end, { nargs = "?", complete = "dir" })


vim.api.nvim_create_user_command("MultiTreeRefresh", function()
  require("multi-tree").refresh_current()
end, {})

vim.api.nvim_create_user_command("MultiTreeClose", function()
  require("multi-tree").close_current()
end, {})

vim.api.nvim_create_user_command("MultiTreeBookmarks", function()
  require("multi-tree.actions").bookmark_jump()
end, {})

vim.api.nvim_create_user_command("MultiTreeBookmarkDelete", function()
  require("multi-tree.actions").bookmark_delete()
end, {})
