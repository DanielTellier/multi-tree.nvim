local M = {}

function M.toggle(node, state)
  if node.type ~= "dir" then return end
  local fs = require("multi-tree.fs")
  local render = require("multi-tree.render")

  fs.ensure_children_loaded(node, state)
  node.expanded = not node.expanded
  render.render(state)
end

function M.change_root(node, state)
  if node.type ~= "dir" then return end
  local utils = require("multi-tree.utils")
  local state_module = require("multi-tree.state")
  local fs = require("multi-tree.fs")
  local render = require("multi-tree.render")

  local npath = utils.normalize_path(node.path)

  -- Add to history
  if not state.dir_history then state.dir_history = {} end
  if state.root_node and state.root_node.path then
    table.insert(state.dir_history, state.root_node.path)
  end
  state.history_index = #state.dir_history + 1

  -- If another tree already has this root, focus it and bail.
  local existing = state_module.find_by_path(npath)
  if existing and existing.buf ~= state.buf then
    state_module.focus_window(existing)
    return
  end

  local new_root = {
    path = npath,
    name = utils.basename_safe(npath),
    type = "dir",
    children = nil,
    expanded = true,
    depth = 0,
  }
  fs.load_children(
    new_root,
    state.opts.show_hidden,
    state.sort_mode or "name"
  )
  state.root_node = new_root

  if state.opts.set_local_cwd then
    pcall(vim.api.nvim_set_current_win, state.win)
    vim.cmd("lcd " .. vim.fn.fnameescape(npath))
  end

  render.render(state)
end

function M.refresh(state)
  local state_module = require("multi-tree.state")
  local fs = require("multi-tree.fs")
  local render = require("multi-tree.render")

  state = state or state_module.get_current()
  if not state then return end

  -- Build a map of expanded paths before refresh
  local expanded_paths = {}
  local function collect_expanded(node)
    if node.type == "dir" and node.expanded then
      expanded_paths[node.path] = true
      if node.children then
        for _, child in ipairs(node.children) do
          collect_expanded(child)
        end
      end
    end
  end
  collect_expanded(state.root_node)

  local function refresh_node(node)
    if node.type ~= "dir" then return end
    local was_expanded = node.expanded
    node.children = fs.scandir(
      node.path,
      state.opts.show_hidden,
      state.sort_mode or "name"
    )
    for _, c in ipairs(node.children) do
      c.depth = node.depth + 1
      -- Restore expanded state from the map
      c.expanded = expanded_paths[c.path] or false
    end
    node.expanded = was_expanded
    if node.children and node.expanded then
      for _, child in ipairs(node.children) do
        if child.type == "dir" and child.expanded then
          refresh_node(child)
        end
      end
    end
  end
  refresh_node(state.root_node)
  render.render(state)
end

function M.open_file(node, how)
  if node.type ~= "file" then return end
  local escaped = vim.fn.fnameescape(node.path)
  if how == "edit" then
    vim.cmd("edit " .. escaped)
  elseif how == "vsplit" then
    vim.cmd("vsplit " .. escaped)
  elseif how == "split" then
    vim.cmd("split " .. escaped)
  elseif how == "tab" then
    vim.cmd("tabedit " .. escaped)
  else
    vim.cmd("edit " .. escaped)
  end
end

return M
