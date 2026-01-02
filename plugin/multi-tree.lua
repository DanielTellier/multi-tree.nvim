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

-- Start with a directory: `nvim .` or `nvim path/`.
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Conventional behavior: only hijack when there is exactly one arg and it's a dir.
    if vim.fn.argc() == 1 then
      local arg = vim.fn.argv(0)
      if arg ~= nil and vim.fn.isdirectory(arg) == 1 then
        -- Optional: set cwd to that directory for the session/tab as you prefer.
        -- vim.cmd("cd " .. vim.fn.fnameescape(arg))
        require("multi-tree").open(vim.fn.fnameescape(arg))
      end
    end
  end,
  once = true,
})

-- Replace :edit . (or :edit <dir>) mid-session in the current window.
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function(ev)
    -- Avoid loops and only act on real directory buffers.
    if ev.file == "" then return end
    if vim.bo[ev.buf].filetype == "multi-tree" then return end
    if vim.fn.isdirectory(ev.file) == 1 then
      -- Use schedule to avoid doing too much during the event itself.
      vim.schedule(function()
        require("multi-tree").open(vim.fn.fnameescape(ev.file))
      end)
    end
  end,
})
