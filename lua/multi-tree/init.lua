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

function M.open(path, open_type)
  local config = require("multi-tree.config")
  local opts = config.get() or {}
  local state_module = require("multi-tree.state")
  local utils = require("multi-tree.utils")
  local fs = require("multi-tree.fs")
  local mappings = require("multi-tree.mappings")
  local render = require("multi-tree.render")

  local abs = utils.normalize_path(path)
  if vim.fn.isdirectory(abs) == 0 then return end
  local root_name = utils.basename_safe(abs)
  local buf_title = root_name

  -- Enforce uniqueness: focus existing tree for this path if
  -- present.
  local existing = state_module.find_by_path(abs)
  if existing and state_module.focus_window(existing) then
    return
  end

  if open_type then
    vim.cmd(open_type)
  end
  local win = vim.api.nvim_get_current_win()
  local buf = create_buffer(win, buf_title)
  local state = state_module.create(win, buf, opts)

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
end

return M
