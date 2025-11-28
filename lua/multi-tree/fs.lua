local M = {}
local uv = vim.loop

function M.scandir(path, show_hidden, sort_mode)
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
      local isdir = (typ == "directory") or
                    (stat and stat.type == "directory")
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

function M.load_children(node, show_hidden, sort_mode)
  if node.type ~= "dir" then return end
  node.children = M.scandir(
    node.path,
    show_hidden,
    sort_mode or "name"
  )
  for _, child in ipairs(node.children) do
    child.depth = node.depth + 1
  end
end

function M.ensure_children_loaded(node, state)
  if node.type ~= "dir" or node.children then return end
  M.load_children(
    node,
    state.opts.show_hidden,
    state.sort_mode or "name"
  )
end

return M
