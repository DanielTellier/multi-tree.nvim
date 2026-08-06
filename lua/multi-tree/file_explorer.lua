--- Makes MultiTree the file explorer for directory buffers, so that
--- `nvim .`, `:e .` and `:e src/` open a tree. Controlled by the
--- `default_file_explorer` option.
local M = {}

--- Remote paths (`scp://`, `sftp://`, `ftp://`, ...) are served by
--- netrw's own "Network" autocommands. MultiTree only browses the
--- local filesystem, so those buffers are never hijacked.
local function is_url(bufname)
  return bufname:find("^%a[%w+.%-]*://") ~= nil
end

--- The local directory a buffer stands for, or nil when it is not a
--- directory buffer.
local function dir_of(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return nil end

  -- netrw may have claimed the buffer before us; it tracks the
  -- browsed directory in a buffer variable.
  if vim.bo[bufnr].filetype == "netrw" then
    local curdir = vim.b[bufnr].netrw_curdir
    if curdir and vim.fn.isdirectory(curdir) == 1 then
      return curdir
    end
  end

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == "" or is_url(bufname) then return nil end
  if vim.fn.isdirectory(bufname) == 0 then return nil end
  return bufname
end

local function window_for(bufnr)
  if vim.api.nvim_get_current_buf() == bufnr then
    return vim.api.nvim_get_current_win()
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end
  return nil
end

--- Replace a directory buffer with a MultiTree view. Returns true
--- when the buffer was taken over.
function M.hijack(bufnr)
  local dir = dir_of(bufnr)
  if not dir then return false end

  local win = window_for(bufnr)
  if not win then return false end
  if vim.api.nvim_get_current_win() ~= win then
    vim.api.nvim_set_current_win(win)
  end

  require("multi-tree").open(dir)

  -- open() either builds a tree here or focuses an existing tree for
  -- this path. Only discard the directory buffer once we know a tree
  -- took over, so a failed open never loses the user's window.
  local hijacked =
    vim.bo[vim.api.nvim_get_current_buf()].filetype == "multi-tree"
  if hijacked and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
  return hijacked
end

local function enabled()
  return require("multi-tree.config").get().default_file_explorer
end

--- Stop netrw from browsing local directories, keeping the rest of
--- netrw intact.
---
--- netrw browses directories from its "FileExplorer" augroup and
--- serves remote urls from "Network", so clearing only the former
--- leaves scp://, sftp:// and friends working as usual.
local function disable_netrw_file_explorer()
  -- On Neovim 0.12+ netrw ships as an opt package that a runtime
  -- shim `packadd`s, which happens *after* this plugin is sourced.
  -- Loading it here means its augroups exist to be cleared;
  -- clearing before it loads would be a silent no-op.
  if not vim.g.loaded_netrwPlugin then
    pcall(vim.cmd, "silent! packadd netrw")
  end

  -- Only clear a group netrw actually registered: creating the
  -- augroup unconditionally would leave an empty one behind and
  -- make netrw look loaded to other plugins.
  local ok, autocmds =
    pcall(vim.api.nvim_get_autocmds, { group = "FileExplorer" })
  if ok and not vim.tbl_isempty(autocmds) then
    vim.api.nvim_create_augroup("FileExplorer", { clear = true })
  end
end

local netrw_disabled = false

--- Disabling is deferred rather than done when this module loads:
--- `setup()` may not have run yet, so acting early could clobber
--- netrw for a user who passes `default_file_explorer = false`.
local function ensure_netrw_disabled()
  if netrw_disabled then return end
  netrw_disabled = true
  disable_netrw_file_explorer()
end

--- Claim whatever directory buffer is already on screen, so that
--- `nvim .` opens a tree rather than netrw.
local function take_over_netrw()
  if not enabled() then return end
  ensure_netrw_disabled()
  M.hijack(vim.api.nvim_get_current_buf())
end

function M.setup()
  local group = vim.api.nvim_create_augroup(
    "multi_tree_file_explorer",
    { clear = true }
  )

  -- BufEnter rather than BufAdd: BufAdd fires only when a buffer is
  -- created, so a directory buffer that already exists when this
  -- autocommand is registered never triggers it, which loses both
  -- `nvim .` and lazy-loading. The extra cost of BufEnter is one
  -- isdirectory() stat per buffer enter.
  vim.api.nvim_create_autocmd("BufEnter", {
    desc = "Open MultiTree instead of netrw for directory buffers",
    group = group,
    pattern = "*",
    nested = true,
    callback = function(params)
      if not enabled() then return end
      -- Disable on the way past the first directory buffer as well
      -- as at VimEnter: when this plugin is lazy-loaded, netrw's
      -- autocommands are already registered and would otherwise
      -- keep claiming directories ahead of us.
      ensure_netrw_disabled()
      M.hijack(params.buf)
    end,
  })

  -- The buffer from `nvim .` is not on screen until VimEnter, and
  -- user setup() has not necessarily run before now.
  if vim.v.vim_did_enter == 1 then
    vim.schedule(take_over_netrw)
  else
    vim.api.nvim_create_autocmd("VimEnter", {
      desc = "Take over netrw's local directory browsing",
      group = group,
      pattern = "*",
      nested = true,
      once = true,
      callback = take_over_netrw,
    })
  end
end

return M
