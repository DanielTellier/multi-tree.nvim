local M = {}

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

function M.open(path)
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
  local buf_title = "MT: " .. root_name

  -- Enforce uniqueness: focus existing tree for this path if
  -- present.
  local existing = state_module.find_by_path(abs)
  if existing and state_module.focus_window(existing) then
    return
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
  state.dir_history = { abs }
  state.history_index = 1

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

--- Locate an existing tree whose root contains `path`. Prefers a
--- tree on the current tab. Returns the state or nil.
local function find_state_containing(path)
  local state_module = require("multi-tree.state")
  local utils = require("multi-tree.utils")
  local current_tab = vim.api.nvim_get_current_tabpage()
  local fallback

  for _, st in pairs(state_module.states) do
    if st.root_node and st.root_node.path and
       vim.api.nvim_win_is_valid(st.win) then
      local root = utils.normalize_path(st.root_node.path)
      if utils.is_subpath(path, root) then
        local tab = vim.api.nvim_win_get_tabpage(st.win)
        if tab == current_tab then
          return st
        end
        fallback = fallback or st
      end
    end
  end
  return fallback
end

local function expand_chain_to(state, path)
  local fs = require("multi-tree.fs")
  local utils = require("multi-tree.utils")

  local root = utils.normalize_path(state.root_node.path)
  local target = utils.normalize_path(path)
  if target == root then return state.root_node end

  local rel = target:sub(#root + 2)
  local parts = vim.split(rel, "/", { plain = true })

  local node = state.root_node
  state.root_node.expanded = true
  fs.ensure_children_loaded(node, state)

  for i, part in ipairs(parts) do
    if not node.children then return nil end
    local found
    for _, child in ipairs(node.children) do
      if child.name == part then
        found = child
        break
      end
    end
    if not found then return nil end
    node = found
    if node.type == "dir" and i < #parts then
      node.expanded = true
      fs.ensure_children_loaded(node, state)
    end
  end
  return node
end

local function place_cursor_on_path(state, path)
  local utils = require("multi-tree.utils")
  local target = utils.normalize_path(path)
  for row, node in pairs(state.line2node) do
    if utils.normalize_path(node.path) == target then
      pcall(vim.api.nvim_set_current_win, state.win)
      pcall(vim.api.nvim_win_set_cursor, state.win, { row, 0 })
      return true
    end
  end
  return false
end

function M.reveal_path(path)
  local utils = require("multi-tree.utils")
  local state_module = require("multi-tree.state")
  local render = require("multi-tree.render")

  local target = utils.normalize_path(path)
  local exists = vim.loop.fs_stat(target)
  if not exists then
    vim.notify(
      "Path does not exist: " .. target,
      vim.log.levels.WARN
    )
    return
  end

  local state = find_state_containing(target)
  if not state then
    local parent
    if exists.type == "directory" then
      parent = target
    else
      parent = vim.fn.fnamemodify(target, ":h")
    end
    M.open(parent)
    state = state_module.find_by_path(parent)
    if not state then return end
  else
    state_module.focus_window(state)
  end

  if expand_chain_to(state, target) then
    render.render(state)
    place_cursor_on_path(state, target)
  end
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
