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

--[[
This needs to be defined in your Lazy config
```
{
  "DanielTellier/multi-tree.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  init = function()
    -- Disable netrw to allow directory hijacking
    -- Must be done before plugin loads
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
  end,
...
}
```
--]]

-- Open MultiTree via: `nvim <.|dir>`
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Conventional behavior: only hijack when there is exactly one arg and it's a dir.
    if vim.fn.argc() == 1 then
      local arg = vim.fn.argv(0)
      if arg ~= nil and vim.fn.isdirectory(arg) == 1 then
        local buf_to_delete = vim.fn.bufnr(arg)
        require("multi-tree").open(vim.fn.fnameescape(arg), {})
        -- -- Clean up the directory buffer after opening multi-tree
        -- if vim.api.nvim_buf_is_valid(buf_to_delete) then
        --   vim.api.nvim_buf_delete(buf_to_delete, { force = true })
        -- end
      end
    end
  end,
  once = true,
})

-- Open MultiTree via: `:edit <.|dir>`
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function(ev)
    -- Avoid loops and only act on real directory buffers.
    if ev.file == "" then return end
    if vim.bo[ev.buf].filetype == "multi-tree" then return end
    if vim.fn.isdirectory(ev.file) == 1 then
      local buf_to_delete = ev.buf
      -- Use schedule to avoid doing too much during the event itself.
      vim.schedule(function()
        require("multi-tree").open(vim.fn.fnameescape(ev.file), {})
        -- -- Clean up the directory buffer after opening multi-tree
        -- if vim.api.nvim_buf_is_valid(buf_to_delete) then
        --   vim.api.nvim_buf_delete(buf_to_delete, { force = true })
        -- end
      end)
    end
  end,
})
