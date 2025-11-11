local M = {}
local uv = vim.loop

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

M.states = {}
M.tab_titles = M.tab_titles or {}
M._tab_counter = M._tab_counter or 0
M.bookmarks = M.bookmarks or {}
M.sort_mode = M.sort_mode or "name" -- "name" or "modified"
M.dir_history = M.dir_history or {} -- per-state history tracking

local defaults = {
  show_hidden = false,
  icons = true,
  indent = 2,
  auto_tab_title = true, -- Create a per-tab title the first time a tree opens in that tab.
  map_next_tab_keys = true, -- set to false if users want to provide their own mappings
  set_local_cwd = true, -- set :lcd to the tree root for the tree window.
  restore_local_cwd_on_close = false, -- restore previous cwd when closing the tree window.
}

-- Return a label for a tabpage (used by Heirline).
function M.tab_title(tab)
  local title = M.tab_titles[tab]
  if title then return title end
  -- Fallback: active window’s buffer tail in that tab.
  local win = vim.api.nvim_tabpage_get_win(tab)
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  return (name ~= "" and vim.fn.fnamemodify(name, ":t")) or "[No Name]"
end

-- Assign a title once per tab the first time a tree opens there.
local function ensure_tab_title_for_current_tab()
  local tab = vim.api.nvim_get_current_tabpage()
  if not M.tab_titles[tab] then
    M._tab_counter = M._tab_counter + 1
    M.tab_titles[tab] = string.format("MultiTree-%d", M._tab_counter)
    vim.cmd("redrawtabline")
  end
end

-- Public rename helper.
function M.tab_rename(new_name)
  if not new_name or new_name == "" then return end
  local tab = vim.api.nvim_get_current_tabpage()
  M.tab_titles[tab] = new_name
  vim.cmd("redrawtabline")
end

-- Optional cleanup when tabs close.
function M.on_tab_closed(tabnr)
  for tab, _ in pairs(M.tab_titles) do
    local ok, nr = pcall(vim.api.nvim_tabpage_get_number, tab)
    if not ok or nr == tabnr then
      M.tab_titles[tab] = nil
    end
  end
end

local function normalize_path(path)
  if vim.fn.has("win32") == 1 then
    path = path:gsub("\\", "/")
  end
  path = vim.fn.fnamemodify(path, ":p")
  -- Strip trailing slashes except on root ("/") or Windows drive roots ("C:/").
  if path ~= "/" and not path:match("^%a:/$") then
    path = path:gsub("/+$", "")
  end
  return path
end

local function basename_safe(path)
  if vim.fs and vim.fs.basename then
    local name = vim.fs.basename(path)
    if name and name ~= "" then return name end
  end
  -- Fallback for older Neovim: handle trailing slash.
  local name = vim.fn.fnamemodify(path, ":t")
  if name == "" then
    name = vim.fn.fnamemodify(path, ":h:t")
  end
  if name == "" then
    name = path
  end
  return name
end

local function icon_for(node, default)
  if not defaults.icons then
    return default or ""
  end
  if node.type == "dir" then
    return " "
  end
  if has_devicons then
    local ext = node.name:match("^.+%.(.+)$")
    local icon, _ = devicons.get_icon(node.name, ext, { default = true })
    if icon then return icon .. " " end
  end
  return " "
end

local function scandir(path, show_hidden, sort_mode)
  local items = {}
  local iter = uv.fs_scandir(path)
  if not iter then return items end

  while true do
    local name, typ = uv.fs_scandir_next(iter)
    if not name then break end
    if not show_hidden and name:sub(1, 1) == "." then
      -- skip
    else
      local full = path .. "/" .. name
      local stat = uv.fs_stat(full)
      local isdir = (typ == "directory") or (stat and stat.type == "directory")
      table.insert(items, {
        path = full,
        name = name,
        type = isdir and "dir" or "file",
        children = nil,
        expanded = false,
        depth = 0,
        mtime = stat and stat.mtime.sec or 0,
      })
    end
  end

  table.sort(items, function(a, b)
    if a.type ~= b.type then return a.type == "dir" end
    if sort_mode == "modified" then
      return a.mtime > b.mtime
    else
      return a.name:lower() < b.name:lower()
    end
  end)

  return items
end

local function load_children(node, show_hidden, sort_mode)
  if node.type ~= "dir" then return end
  node.children = scandir(node.path, show_hidden, sort_mode or "name")
  for _, child in ipairs(node.children) do
    child.depth = node.depth + 1
  end
end

local function build_visible(root)
  local out = {}
  local function walk(n)
    table.insert(out, n)
    if n.type == "dir" and n.expanded and n.children then
      for _, c in ipairs(n.children) do
        walk(c)
      end
    end
  end
  walk(root)
  return out
end

local function render(state)
  local buf = state.buf

    -- Make sure we can update without warnings.
  vim.bo[buf].readonly = false
  vim.bo[buf].modifiable = true

  local root = state.root_node
  local lines = {}
  local line2node = {}

  local visible = build_visible(root)
  for i, node in ipairs(visible) do
    local indent = string.rep(" ", defaults.indent * node.depth)
    local marker = ""
    if node.type == "dir" then
      marker = node.expanded and "▾ " or "▸ "
    else
      marker = "  "
    end
    local ico = icon_for(node, "")
    lines[i] = indent .. marker .. ico .. node.name
    line2node[i] = node
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  state.line2node = line2node
end

local function get_node_under_cursor(state)
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.line2node and state.line2node[row] or nil
end

local function ensure_children_loaded(node, state)
  if node.type ~= "dir" then return end
  if node.children == nil then
    load_children(node, state.opts.show_hidden, state.sort_mode or "name")
  end
end

local function toggle(node, state)
  if node.type ~= "dir" then return end
  ensure_children_loaded(node, state)
  node.expanded = not node.expanded
  render(state)
end

local function change_root(node, state)
  if node.type ~= "dir" then return end
  local npath = normalize_path(node.path)

  -- Add to history
  if not state.dir_history then state.dir_history = {} end
  if state.root_node and state.root_node.path then
    table.insert(state.dir_history, state.root_node.path)
  end
  state.history_index = #state.dir_history + 1

  -- If another tree already has this root, focus it and bail.
  do
    local existing = find_existing_tree_for_path(npath)
    if existing and existing.buf ~= state.buf then
      focus_tree_window(existing)
      return
    end
  end

  local new_root = {
    path = npath,
    name = basename_safe(npath),
    type = "dir",
    children = nil,
    expanded = true,
    depth = 0,
  }
  load_children(new_root, state.opts.show_hidden, state.sort_mode or "name")
  state.root_node = new_root

  if state.opts.set_local_cwd then
    -- Ensure we set local cwd for the tree window.
    pcall(vim.api.nvim_set_current_win, state.win)
    vim.cmd("lcd " .. vim.fn.fnameescape(npath))
  end

  render(state)
end

local function open_file(node, how)
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

local function open_file_in_current_window(state, node, how)
  if node.type ~= "file" then return end
  -- The current window is the tree window; its local cwd has already been set in M.open.
  local escaped = vim.fn.fnameescape(node.path)
  if how == "vsplit" then
    vim.cmd("vsplit " .. escaped)
  elseif how == "split" then
    vim.cmd("split " .. escaped)
  elseif how == "tab" then
    vim.cmd("tabedit " .. escaped)
  else
    vim.cmd("edit " .. escaped)
  end
end

local function toggle_sort(state)
  state.sort_mode = state.sort_mode == "name" and "modified" or "name"
  M.refresh(state)
  local msg = "Sort: " .. (state.sort_mode == "name" and "Name" or "Modified")
  vim.notify(msg, vim.log.levels.INFO)
end

local function create_file(state)
  local node = get_node_under_cursor(state)
  if not node then return end

  local dir_path = node.type == "dir" and node.path or vim.fn.fnamemodify(node.path, ":h")

  vim.ui.input({ prompt = "New file name: " }, function(name)
    if not name or name == "" then return end

    local file_path = dir_path .. "/" .. name
    local file = io.open(file_path, "w")
    if file then
      file:close()
      M.refresh(state)
      vim.notify("Created: " .. name, vim.log.levels.INFO)
    else
      vim.notify("Failed to create: " .. name, vim.log.levels.ERROR)
    end
  end)
end

local function create_directory(state)
  local node = get_node_under_cursor(state)
  if not node then return end

  local dir_path = node.type == "dir" and node.path or vim.fn.fnamemodify(node.path, ":h")

  vim.ui.input({ prompt = "New directory name: " }, function(name)
    if not name or name == "" then return end

    local new_dir = dir_path .. "/" .. name
    local ok = vim.fn.mkdir(new_dir, "p")
    if ok == 1 then
      M.refresh(state)
      vim.notify("Created directory: " .. name, vim.log.levels.INFO)
    else
      vim.notify("Failed to create directory: " .. name, vim.log.levels.ERROR)
    end
  end)
end

local function rename_file(state)
  local node = get_node_under_cursor(state)
  if not node then return end

  vim.ui.input({
    prompt = "Rename to: ",
    default = node.name
  }, function(new_name)
    if not new_name or new_name == "" or new_name == node.name then return end

    local dir = vim.fn.fnamemodify(node.path, ":h")
    local new_path = dir .. "/" .. new_name

    local ok = vim.fn.rename(node.path, new_path)
    if ok == 0 then
      M.refresh(state)
      vim.notify("Renamed: " .. node.name .. " -> " .. new_name, vim.log.levels.INFO)
    else
      vim.notify("Failed to rename: " .. node.name, vim.log.levels.ERROR)
    end
  end)
end

local function delete_file(state)
  local node = get_node_under_cursor(state)
  if not node then return end

  local prompt = string.format("Delete %s '%s'? (y/N): ",
    node.type == "dir" and "directory" or "file", node.name)

  vim.ui.input({ prompt = prompt }, function(input)
    if input and input:lower() == "y" then
      local ok
      if node.type == "dir" then
        ok = vim.fn.delete(node.path, "rf") -- recursive force
      else
        ok = vim.fn.delete(node.path)
      end

      if ok == 0 then
        M.refresh(state)
        vim.notify("Deleted: " .. node.name, vim.log.levels.INFO)
      else
        vim.notify("Failed to delete: " .. node.name, vim.log.levels.ERROR)
      end
    end
  end)
end

local function add_bookmark(state)
  local node = get_node_under_cursor(state)
  if not node then return end

  vim.ui.input({ prompt = "Bookmark name (or press Enter for default): " }, function(name)
    local bookmark_name = name and name ~= "" and name or node.name
    M.bookmarks[bookmark_name] = node.path
    vim.notify("Bookmarked: " .. bookmark_name .. " -> " .. node.path, vim.log.levels.INFO)
  end)
end

local function delete_bookmark(state, count)
  if not next(M.bookmarks) then
    vim.notify("No bookmarks to delete", vim.log.levels.WARN)
    return
  end

  if count and count > 0 then
    local bookmark_list = {}
    for name, _ in pairs(M.bookmarks) do
      table.insert(bookmark_list, name)
    end
    table.sort(bookmark_list)

    if count <= #bookmark_list then
      local bookmark_name = bookmark_list[count]
      M.bookmarks[bookmark_name] = nil
      vim.notify("Deleted bookmark: " .. bookmark_name, vim.log.levels.INFO)
    else
      vim.notify("Invalid bookmark number", vim.log.levels.ERROR)
    end
  else
    -- Show list and let user pick
    local items = {}
    for name, path in pairs(M.bookmarks) do
      table.insert(items, name .. " -> " .. path)
    end

    if #items == 0 then
      vim.notify("No bookmarks found", vim.log.levels.WARN)
      return
    end

    vim.ui.select(items, {
      prompt = "Delete bookmark:",
    }, function(choice)
      if choice then
        local bookmark_name = choice:match("^([^%s]+)")
        M.bookmarks[bookmark_name] = nil
        vim.notify("Deleted bookmark: " .. bookmark_name, vim.log.levels.INFO)
      end
    end)
  end
end

local function list_bookmarks()
  if not next(M.bookmarks) then
    vim.notify("No bookmarks found", vim.log.levels.INFO)
    return
  end

  local lines = { "Bookmarks:" }
  local i = 1
  for name, path in pairs(M.bookmarks) do
    table.insert(lines, string.format("%d. %s -> %s", i, name, path))
    i = i + 1
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

local function goto_bookmark(state, count)
  if not next(M.bookmarks) then
    vim.notify("No bookmarks found", vim.log.levels.WARN)
    return
  end

  if count and count > 0 then
    local bookmark_list = {}
    for name, path in pairs(M.bookmarks) do
      table.insert(bookmark_list, { name = name, path = path })
    end
    table.sort(bookmark_list, function(a, b) return a.name < b.name end)

    if count <= #bookmark_list then
      local bookmark = bookmark_list[count]
      local bookmark_node = {
        path = bookmark.path,
        name = basename_safe(bookmark.path),
        type = "dir",
      }
      change_root(bookmark_node, state)
      vim.notify("Opened bookmark: " .. bookmark.name, vim.log.levels.INFO)
    else
      vim.notify("Invalid bookmark number", vim.log.levels.ERROR)
    end
  else
    -- Show selection menu
    local items = {}
    local bookmark_map = {}
    for name, path in pairs(M.bookmarks) do
      local display = name .. " -> " .. path
      table.insert(items, display)
      bookmark_map[display] = { name = name, path = path }
    end

    vim.ui.select(items, {
      prompt = "Go to bookmark:",
    }, function(choice)
      if choice then
        local bookmark = bookmark_map[choice]
        local bookmark_node = {
          path = bookmark.path,
          name = basename_safe(bookmark.path),
          type = "dir",
        }
        change_root(bookmark_node, state)
        vim.notify("Opened bookmark: " .. bookmark.name, vim.log.levels.INFO)
      end
    end)
  end
end

local function open_file_in_prev_window(state, node)
  if node.type ~= "file" then return end
  local prev = vim.fn.winnr("#")
  if prev ~= 0 then
    vim.cmd("wincmd p")
    if state.opts.set_local_cwd and state.root_node and state.root_node.path then
      vim.cmd("lcd " .. vim.fn.fnameescape(state.root_node.path))
    end
    open_file_in_current_window(state, node, "edit")
    vim.cmd("wincmd p")
  else
    -- No previous window; open in the tree window.
    open_file_in_current_window(state, node, "edit")
  end
end

local function attach_mappings(state)
  local buf = state.buf

  local function nmap(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
  end

  nmap("<CR>", function()
    local node = get_node_under_cursor(state)
    if not node then return end
    if node.type == "dir" then
      toggle(node, state)
    else
      open_file_in_prev_window(state, node)
    end
  end, "Open file or toggle directory.")

  nmap("l", function()
    local node = get_node_under_cursor(state)
    if not node then return end
    if node.type == "dir" then
      if not node.expanded then
        toggle(node, state)
      end
    else
      open_file(node, "edit")
    end
  end, "Expand directory or open file.")

  nmap("h", function()
    local node = get_node_under_cursor(state)
    if not node then return end
    if node.type == "dir" and node.expanded then
      toggle(node, state)
    else
      local row = vim.api.nvim_win_get_cursor(state.win)[1]
      local cur = state.line2node[row]
      for i = row - 1, 1, -1 do
        local candidate = state.line2node[i]
        if candidate and candidate.type == "dir" and candidate.depth == (cur.depth - 1) then
          candidate.expanded = false
          render(state)
          break
        end
      end
    end
  end, "Collapse directory.")

  nmap("s", function()
    local node = get_node_under_cursor(state)
    if node and node.type == "file" then
      open_file_in_current_window(state, node, "split")
    end
  end, "Open file in horizontal split.")

  nmap("v", function()
    local node = get_node_under_cursor(state)
    if node and node.type == "file" then
      open_file_in_current_window(state, node, "vsplit")
    end
  end, "Open file in vertical split.")

  nmap("t", function()
    local node = get_node_under_cursor(state)
    if node and node.type == "file" then
      open_file_in_current_window(state, node, "tab")
    end
  end, "Open file in new tab.")

  nmap("C", function()
    local node = get_node_under_cursor(state)
    if node then change_root(node, state) end
  end, "Change root to selected directory.")

  nmap("r", function() M.refresh(state) end, "Refresh tree.")
  nmap("q", function() M.close(state) end, "Close tree buffer.")

  -- Netrw-style mappings
  nmap("s", function() toggle_sort(state) end, "Toggle sort mode.")
  nmap("%", function() create_file(state) end, "Create new file.")
  nmap("d", function() create_directory(state) end, "Create new directory.")
  nmap("R", function() rename_file(state) end, "Rename file/directory.")
  nmap("D", function() delete_file(state) end, "Delete file/directory.")
  nmap("mb", function() add_bookmark(state) end, "Bookmark current file/directory.")
  nmap("mB", function()
    local count = vim.v.count > 0 and vim.v.count or nil
    delete_bookmark(state, count)
  end, "Delete bookmark.")
  nmap("qb", function() list_bookmarks() end, "List bookmarks.")
  nmap("gb", function()
    local count = vim.v.count > 0 and vim.v.count or nil
    goto_bookmark(state, count)
  end, "Go to bookmark.")

  if state.opts.map_next_tab_keys then
    nmap("<leader>i", function()
      M.open_current_node_in_next_tab("edit", false)
    end, "Open file on next tab.")

    nmap("<leader>I", function()
      M.open_current_node_in_next_tab("edit", true)
    end, "Open file on next tab and stay in tree.")

    nmap("<leader>o", function()
      M.open_current_node_in_next_tab("split", false)
    end, "Open file in horizontal split on next tab.")

    nmap("<leader>O", function()
      M.open_current_node_in_next_tab("split", true)
    end, "Open file in horizontal split on next tab and stay in tree.")

    nmap("<leader>v", function()
      M.open_current_node_in_next_tab("vsplit", false)
    end, "Open file in vertical split on next tab.")

    nmap("<leader>V", function()
      M.open_current_node_in_next_tab("vsplit", true)
    end, "Open file in vertical split on next tab and stay in tree.")
  end
end

-- Create the tree buffer in the given window.
-- listed controls whether this buffer participates in Neovim’s normal buffer list:
--   - listed = false (default): The buffer is unlisted. It won’t appear in :ls/:buffers,
--     won’t be cycled by :bnext/:bprev, and most bufferline plugins will hide it.
--     This is recommended for sidebar/explorer buffers to avoid cluttering buffer navigation.
--   - listed = true: The buffer is listed. It will show up in :ls/:buffers, be included
--     in :bnext/:bprev cycles, and appear in bufferline plugins. Use this if you want
--     the tree to be selectable like regular file buffers.
local function create_buffer(win, title, listed)
  listed = listed or false -- default: unlisted scratch buffer
  local buf = vim.api.nvim_create_buf(listed, true)
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

-- Find an existing tree instance for the normalized path.
-- Prefer one in the current tab; otherwise return the first valid match.
local function find_existing_tree_for_path(abs)
  local current_tab = vim.api.nvim_get_current_tabpage()
  local candidate_any
  for _, st in pairs(M.states) do
    if st.root_node and st.root_node.path and vim.api.nvim_win_is_valid(st.win) then
      if normalize_path(st.root_node.path) == abs then
        local tab = vim.api.nvim_win_get_tabpage(st.win)
        if tab == current_tab then
          return st
        end
        candidate_any = candidate_any or st
      end
    end
  end
  return candidate_any
end

-- Focus the window for a given tree state, switching tabs if needed.
local function focus_tree_window(state)
  if not state or not vim.api.nvim_win_is_valid(state.win) then
    return false
  end
  local tab = vim.api.nvim_win_get_tabpage(state.win)
  local nr = vim.api.nvim_tabpage_get_number(tab)
  vim.cmd(("%dtabnext"):format(nr))
  vim.api.nvim_set_current_win(state.win)
  return true
end

function M.open(path, opts)
  local win = vim.api.nvim_get_current_win()
  local abs = normalize_path(path)
  local root_name = basename_safe(abs)
  local buf_title = "MultiTree: " .. root_name

  local merged_opts = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Enforce uniqueness: focus existing tree for this path if present.
  do
    local existing = find_existing_tree_for_path(abs)
    if existing and focus_tree_window(existing) then
      return
    end
  end

  local buf = create_buffer(win, buf_title)
  local state = {
    win = win,
    buf = buf,
    opts = merged_opts,
    root_node = nil,
    line2node = {},
    prev_cwd = vim.fn.getcwd(), -- store current cwd to optionally restore later
    sort_mode = "name", -- default sort mode
    dir_history = {}, -- directory navigation history
    history_index = 1, -- current position in history
  }

  -- Create a per-tab title unless explicitly disabled.
  if state.opts.auto_tab_title ~= false then
    ensure_tab_title_for_current_tab()
  end

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

  load_children(root, state.opts.show_hidden, state.sort_mode)
  state.root_node = root

  M.states[buf] = state
  attach_mappings(state)
  render(state)

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    buffer = state.buf,
    callback = function()
      -- Optional: restore local cwd when the tree buffer is closed.
      if state.opts.restore_local_cwd_on_close and state.prev_cwd then
        pcall(vim.api.nvim_set_current_win, state.win)
        pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(state.prev_cwd))
      end
      M.states[state.buf] = nil
    end,
  })
end

function M.refresh(state)
  state = state or M.states[vim.api.nvim_get_current_buf()]
  if not state then return end
  local function refresh_node(node)
    if node.type ~= "dir" then return end
    local was_expanded = node.expanded
    node.children = scandir(node.path, state.opts.show_hidden, state.sort_mode or "name")
    for _, c in ipairs(node.children) do
      c.depth = node.depth + 1
      c.expanded = false
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
  render(state)
end

function M.refresh_current()
  local state = M.states[vim.api.nvim_get_current_buf()]
  if state then M.refresh(state) end
end

function M.close(state)
  state = state or M.states[vim.api.nvim_get_current_buf()]
  if not state then return end
  if vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
end

function M.close_current()
  local state = M.states[vim.api.nvim_get_current_buf()]
  if state then M.close(state) end
end

-- Open a path in the next tab (creating it if necessary).
-- how: "edit" | "split" | "vsplit"
-- stay: when true, return to the original tab after opening.
local function open_path_in_next_tab(path, how, stay)
  local cur = vim.fn.tabpagenr()
  local next_tab = cur + 1
  local last = vim.fn.tabpagenr("$")

  local effective = how
  if next_tab > last then
    vim.cmd("tabnew")
    effective = "edit"
  else
    vim.cmd(("%dtabnext"):format(next_tab))
  end

  local escaped = vim.fn.fnameescape(path)
  if effective == "vsplit" then
    vim.cmd("vsplit " .. escaped)
  elseif effective == "split" then
    vim.cmd("split " .. escaped)
  else
    vim.cmd("edit " .. escaped)
  end

  if stay then
    local prev = vim.fn.tabpagenr("#")
    if prev ~= 0 then
      vim.cmd(("%dtabnext"):format(prev))
    end
  end
end

local function open_path_in_next_tab_with_cwd(path, cwd, how, stay)
  local cur = vim.fn.tabpagenr()
  local next_tab = cur + 1
  local last = vim.fn.tabpagenr("$")

  local effective = how
  if next_tab > last then
    vim.cmd("tabnew")
    effective = "edit"
  else
    vim.cmd(("%dtabnext"):format(next_tab))
  end

  if cwd and cwd ~= "" then
    vim.cmd("lcd " .. vim.fn.fnameescape(cwd))
  end

  local escaped = vim.fn.fnameescape(path)
  if effective == "vsplit" then
    vim.cmd("vsplit " .. escaped)
  elseif effective == "split" then
    vim.cmd("split " .. escaped)
  else
    vim.cmd("edit " .. escaped)
  end

  if stay then
    local prev = vim.fn.tabpagenr("#")
    if prev ~= 0 then
      vim.cmd(("%dtabnext"):format(prev))
    end
  end
end

-- Public: open the node under cursor (in the current MultiTree buffer) in the next tab.
-- how: "edit" | "split" | "vsplit"
-- stay: boolean
function M.open_current_node_in_next_tab(how, stay)
  local buf = vim.api.nvim_get_current_buf()
  local state = M.states[buf]
  if not state then return end
  local node = get_node_under_cursor(state)
  if not node or node.type ~= "file" then return end
  open_path_in_next_tab_with_cwd(node.path, state.root_node and state.root_node.path or nil, how, stay)
end

-- Optional: expose raw path opener for users who want to bypass cursor node.
function M.open_path_in_next_tab(path, how, stay)
  open_path_in_next_tab(path, how, stay)
end

function M.setup(opts)
  defaults = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
