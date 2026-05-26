local M = {}

local items = nil

local function bookmarks_path()
  return vim.fn.stdpath("data") .. "/multi-tree/bookmarks.json"
end

local function ensure_loaded()
  if items ~= nil then return end
  items = {}
  local file = bookmarks_path()
  local fd = io.open(file, "r")
  if not fd then return end
  local content = fd:read("*a")
  fd:close()
  if not content or content == "" then return end
  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    for _, entry in ipairs(decoded) do
      if type(entry) == "table" and
         type(entry.label) == "string" and
         type(entry.path) == "string" then
        table.insert(items, {
          label = entry.label,
          path = entry.path,
        })
      end
    end
  end
end

local function persist()
  local file = bookmarks_path()
  local dir = vim.fn.fnamemodify(file, ":h")
  vim.fn.mkdir(dir, "p")
  local encoded = vim.json.encode(items)
  local fd = io.open(file, "w")
  if not fd then
    vim.notify(
      "Could not write bookmarks file: " .. file,
      vim.log.levels.ERROR
    )
    return
  end
  fd:write(encoded)
  fd:close()
end

function M.list()
  ensure_loaded()
  local copy = {}
  for i, entry in ipairs(items) do
    copy[i] = { label = entry.label, path = entry.path }
  end
  return copy
end

function M.find(label)
  ensure_loaded()
  for _, entry in ipairs(items) do
    if entry.label == label then return entry end
  end
end

function M.add(label, path)
  ensure_loaded()
  for _, entry in ipairs(items) do
    if entry.label == label then
      entry.path = path
      persist()
      return
    end
  end
  table.insert(items, { label = label, path = path })
  persist()
end

function M.remove(label)
  ensure_loaded()
  for i, entry in ipairs(items) do
    if entry.label == label then
      table.remove(items, i)
      persist()
      return true
    end
  end
  return false
end

return M
