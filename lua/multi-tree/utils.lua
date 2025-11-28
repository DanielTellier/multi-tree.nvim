local M = {}

function M.normalize_path(path)
  if vim.fn.has("win32") == 1 then
    path = path:gsub("\\", "/")
  end
  path = vim.fn.fnamemodify(path, ":p")
  -- Strip trailing slashes except on root ("/") or Windows drive
  -- roots ("C:/").
  if path ~= "/" and not path:match("^%a:/$") then
    path = path:gsub("/+$", "")
  end
  return path
end

function M.basename_safe(path)
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

function M.icon_for(node, default)
  local config = require("multi-tree.config").get()
  if not config.icons then
    return default or ""
  end
  if node.type == "dir" then
    return " "
  end
  local has_devicons, devicons = pcall(require, "nvim-web-devicons")
  if has_devicons then
    local ext = node.name:match("^.+%.(.+)$")
    local icon, _ = devicons.get_icon(
      node.name,
      ext,
      { default = true }
    )
    if icon then return icon .. " " end
  end
  return " "
end

return M
