local M = {}

M.bookmarks = M.bookmarks or {}

local function create_buffer(win, title)
  local buf = vim.api.nvim_create_buf(false, true)
  if title and title ~= "" then
    vim.api.nvim_buf_set_name(buf, title)
  end

  vim.api.nvim_win_set_buf(win, buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "multi-tree"
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = false
  vim.wo[win].cursorline = true
  return buf
end

function M.open(path, opts)
  local config = require("multi-tree.config")
  local state_module = require("multi-tree.state")
  local utils = require("multi-tree.utils")
  local fs = require("multi-tree.fs")
  local mappings = require("multi-tree.mappings")
  local render = require("multi-tree.render")

  local win = vim.api.nvim_get_current_win()
  local abs = utils.normalize_path(path)
  local root_name = utils.basename_safe(abs)
  local buf_title = root_name

  local merged_opts = vim.tbl_deep_extend(
    "force",
    config.get(),
    opts or {}
  )

  -- Enforce uniqueness: focus existing tree for this path if
  -- present.
  local existing = state_module.find_by_path(abs)
  if existing and state_module.focus_window(existing) then
    return
  end

  local buf = create_buffer(win, buf_title)
  local state = state_module.create(win, buf, merged_opts)

  if state.opts.set_local_cwd then
    vim.cmd("lcd " .. vim.fn.fnameescape(abs))
  end

  local root = {
    path = abs,
    name = root_name,
    type = "dir",
    children = nil,
    expanded = true,
    depth = 0,
  }

  fs.load_children(root, state.opts.show_hidden, state.sort_mode)
  state.root_node = root

  mappings.attach(state)
  render.render(state)

  vim.api.nvim_create_autocmd(
    { "BufWipeout", "BufUnload" },
    {
      buffer = state.buf,
      callback = function()
        if state.opts.restore_local_cwd_on_close and
           state.prev_cwd then
          pcall(vim.api.nvim_set_current_win, state.win)
          pcall(
            vim.cmd,
            "lcd " .. vim.fn.fnameescape(state.prev_cwd)
          )
        end
        state_module.remove(state.buf)
      end,
    }
  )
end

function M.refresh(state)
  local tree = require("multi-tree.tree")
  tree.refresh(state)
end

function M.refresh_current()
  local state_module = require("multi-tree.state")
  local state = state_module.get_current()
  if state then M.refresh(state) end
end

function M.close(state)
  local state_module = require("multi-tree.state")
  state = state or state_module.get_current()
  if not state then return end
  if vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
end

function M.close_current()
  local state_module = require("multi-tree.state")
  local state = state_module.get_current()
  if state then M.close(state) end
end

function M.setup(opts)
  local config = require("multi-tree.config")
  config.setup(opts)
  local conf_opts = config.get()

  if conf_opts.disable_netrw then
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
        opts = {
          disable_netrw = true,
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
            require("multi-tree").open(vim.fn.fnameescape(arg))
            -- Clean up the directory buffer after opening multi-tree
            if vim.api.nvim_buf_is_valid(buf_to_delete) then
              vim.api.nvim_buf_delete(buf_to_delete, { force = true })
            end
          end
        end
      end,
      once = true,
    })

    -- Open MultiTree via: `:edit <.|dir>`
    vim.api.nvim_create_autocmd("BufEnter", {
      group = vim.api.nvim_create_augroup("MultiTreeDirHijack", { clear = true }),
      callback = function(ev)
        -- Avoid loops and only act on real directory buffers.
        if ev.file == "" then return end
        if vim.bo[ev.buf].filetype == "multi-tree" then return end
        if vim.fn.isdirectory(ev.file) == 1 then
          local buf_to_delete = ev.buf
          -- Use schedule to avoid doing too much during the event itself.
          vim.schedule(function()
            require("multi-tree").open(vim.fn.fnameescape(ev.file))
            -- Clean up the directory buffer after opening multi-tree
            if vim.api.nvim_buf_is_valid(buf_to_delete) then
              vim.api.nvim_buf_delete(buf_to_delete, { force = true })
            end
          end)
        end
      end,
    })
  end
end

return M
