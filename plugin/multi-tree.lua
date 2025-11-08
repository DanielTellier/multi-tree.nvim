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

-- Auto-enable the custom tabline.
vim.o.showtabline = 2
vim.o.tabline = "%!v:lua.require('multi-tree').tabline()"

-- Keep tab titles clean when tabs close.
vim.api.nvim_create_autocmd("TabClosed", {
  callback = function(ev)
    local nr = tonumber(ev.match)
    pcall(function() require("multi-tree").on_tab_closed(nr) end)
  end,
})
