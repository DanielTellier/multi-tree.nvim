local M = {}
local uv = vim.loop

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

M.states = {}
M._id_counter = 0
M._tab_counter = 0
M.tab_titles = {}

local defaults = {
  show_hidden = false,
  icons = true,
  indent = 2,
}

local function _ensure_tab_title_for_current_tab()
  local tab = vim.api.nvim_get_current_tabpage()
  if not M.tab_titles[tab] then
    M._tab_counter = M._tab_counter + 1
    M.tab_titles[tab] = string.format("MultiTree-%d", M._tab_counter)
    vim.cmd("redrawtabline")
  end
end

function M.tabline()
  local s = ""
  local tabs = vim.api.nvim_list_tabpages()
  local current = vim.api.nvim_get_current_tabpage()
  for _, tab in ipairs(tabs) do
    local nr = vim.api.nvim_tabpage_get_number(tab)
    s = s .. "%" .. nr .. "T"
    s = s .. (tab == current and "%#TabLineSel#" or "%#TabLine#")
    local label = M.tab_titles[tab]
    if not label then
      -- Fallback: active window’s buffer tail in that tab.
      local win = vim.api.nvim_tabpage_get_win(tab)
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf)
      label = (name ~= "" and vim.fn.fnamemodify(name, ":t")) or "[No Name]"
    end
    s = s .. " " .. label .. " "
  end
  s = s .. "%#TabLineFill#%="
  return s
end

function M.on_tab_closed(tabnr)
  -- Remove any entry whose number matches tabnr (handles tab handle invalidation).
  for tab, _ in pairs(M.tab_titles) do
    if pcall(vim.api.nvim_tabpage_get_number, tab) then
      if vim.api.nvim_tabpage_get_number(tab) == tabnr then
        M.tab_titles[tab] = nil
      end
    else
      M.tab_titles[tab] = nil
    end
  end
end

function M.tab_rename(new_name)
  if not new_name or new_name == "" then return end
  local tab = vim.api.nvim_get_current_tabpage()
  M.tab_titles[tab] = new_name
  vim.cmd("redrawtabline") -- refresh the tabline immediately
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

local function scandir(path, show_hidden)
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
      })
    end
  end

  table.sort(items, function(a, b)
    if a.type ~= b.type then return a.type == "dir" end
    return a.name:lower() < b.name:lower()
  end)

  return items
end

local function load_children(node, show_hidden)
  if node.type ~= "dir" then return end
  node.children = scandir(node.path, show_hidden)
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
    load_children(node, state.opts.show_hidden)
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
  local new_root = {
    path = npath,
    name = basename_safe(npath),
    type = "dir",
    children = nil,
    expanded = true,
    depth = 0,
  }
  load_children(new_root, state.opts.show_hidden)
  state.root_node = new_root
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
      local prev = vim.fn.winnr("#")
      if prev ~= 0 then
        vim.cmd("wincmd p")
        open_file(node, "edit")
        vim.cmd("wincmd p")
      else
        open_file(node, "edit")
      end
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
    if not node then return end
    if node.type == "file" then
      open_file(node, "split")
    end
  end, "Open file in horizontal split.")

  nmap("v", function()
    local node = get_node_under_cursor(state)
    if not node then return end
    if node.type == "file" then
      open_file(node, "vsplit")
    end
  end, "Open file in vertical split.")

  nmap("t", function()
    local node = get_node_under_cursor(state)
    if not node then return end
    if node.type == "file" then
      open_file(node, "tab")
    end
  end, "Open file in new tab.")

  nmap("C", function()
    local node = get_node_under_cursor(state)
    if node then change_root(node, state) end
  end, "Change root to selected directory.")

  nmap("r", function() M.refresh(state) end, "Refresh tree.")
  nmap("q", function() M.close(state) end, "Close tree buffer.")
end

local function create_buffer(win)
  local buf = vim.api.nvim_create_buf(true, true)
  M._id_counter = M._id_counter + 1
  local title = string.format("MultiTree-%d", M._id_counter)
  vim.api.nvim_buf_set_name(buf, title)

  vim.api.nvim_win_set_buf(win, buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "multi-tree"
  vim.bo[buf].modifiable = false
  vim.wo[win].cursorline = true
  return buf
end

function M.open(path, opts)
  local win = vim.api.nvim_get_current_win()
  local buf = create_buffer(win)

  _ensure_tab_title_for_current_tab()

  -- Assign per-tab title if missing.
  local tab = vim.api.nvim_get_current_tabpage()
  if not M.tab_titles[tab] then
    M._tab_counter = M._tab_counter + 1
    M.tab_titles[tab] = string.format("MultiTree-%d", M._tab_counter)
  end

  local state = {
    win = win,
    buf = buf,
    opts = vim.tbl_deep_extend("force", defaults, opts or {}),
    root_node = nil,
    line2node = {},
  }

  local abs = normalize_path(path)
  local root = {
    path = abs,
    name = basename_safe(abs),
    type = "dir",
    children = nil,
    expanded = true,
    depth = 0,
  }

  load_children(root, state.opts.show_hidden)
  state.root_node = root

  M.states[buf] = state
  attach_mappings(state)
  render(state)

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    buffer = buf,
    callback = function()
      M.states[buf] = nil
    end,
  })
end

function M.refresh(state)
  state = state or M.states[vim.api.nvim_get_current_buf()]
  if not state then return end
  local function refresh_node(node)
    if node.type ~= "dir" then return end
    local was_expanded = node.expanded
    node.children = scandir(node.path, state.opts.show_hidden)
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

function M.setup(opts)
  defaults = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
