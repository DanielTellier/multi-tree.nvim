local M = {}
local uv = vim.loop

function M.toggle_sort(state)
  local tree = require("multi-tree.tree")
  state.sort_mode = state.sort_mode == "name" and
                    "modified" or "name"
  tree.refresh(state)
  local msg = "Sort: " ..
              (state.sort_mode == "name" and "Name" or "Modified")
  vim.notify(msg, vim.log.levels.INFO)
end

function M.toggle_hidden(state)
  local tree = require("multi-tree.tree")
  state.opts.show_hidden = not state.opts.show_hidden
  tree.refresh(state)
  local msg = "Hidden files: " ..
              (state.opts.show_hidden and "shown" or "hidden")
  vim.notify(msg, vim.log.levels.INFO)
end

function M.create_file(state)
  local render = require("multi-tree.render")
  local tree = require("multi-tree.tree")
  local node = render.get_node_under_cursor(state)
  if not node then return end

  local dir_path = node.type == "dir" and node.path or
                   vim.fn.fnamemodify(node.path, ":h")

  vim.ui.input({ prompt = "New file name: " }, function(name)
    if not name or name == "" then return end

    local file_path = dir_path .. "/" .. name
    local file = io.open(file_path, "w")
    if file then
      file:close()
      tree.refresh(state)
      vim.notify("Created: " .. name, vim.log.levels.INFO)
    else
      vim.notify(
        "Failed to create: " .. name,
        vim.log.levels.ERROR
      )
    end
  end)
end

function M.create_directory(state)
  local render = require("multi-tree.render")
  local tree = require("multi-tree.tree")
  local node = render.get_node_under_cursor(state)
  if not node then return end

  local dir_path = node.type == "dir" and node.path or
                   vim.fn.fnamemodify(node.path, ":h")

  vim.ui.input(
    { prompt = "New directory name: " },
    function(name)
      if not name or name == "" then return end

      local new_dir = dir_path .. "/" .. name
      local ok = vim.fn.mkdir(new_dir, "p")
      if ok == 1 then
        tree.refresh(state)
        vim.notify(
          "Created directory: " .. name,
          vim.log.levels.INFO
        )
      else
        vim.notify(
          "Failed to create directory: " .. name,
          vim.log.levels.ERROR
        )
      end
    end
  )
end

function M.rename_file(state)
  local render = require("multi-tree.render")
  local tree = require("multi-tree.tree")
  local node = render.get_node_under_cursor(state)
  if not node then return end

  vim.ui.input({
    prompt = "Rename to: ",
    default = node.name
  }, function(new_name)
    if not new_name or new_name == "" or
       new_name == node.name then
      return
    end

    local dir = vim.fn.fnamemodify(node.path, ":h")
    local new_path = dir .. "/" .. new_name

    local ok = vim.fn.rename(node.path, new_path)
    if ok == 0 then
      tree.refresh(state)
      vim.notify(
        "Renamed: " .. node.name .. " -> " .. new_name,
        vim.log.levels.INFO
      )
    else
      vim.notify(
        "Failed to rename: " .. node.name,
        vim.log.levels.ERROR
      )
    end
  end)
end

function M.delete_file(state)
  local render = require("multi-tree.render")
  local tree = require("multi-tree.tree")
  local node = render.get_node_under_cursor(state)
  if not node then return end

  local prompt = string.format(
    "Delete %s '%s'? (y/N): ",
    node.type == "dir" and "directory" or "file",
    node.name
  )

  vim.ui.input({ prompt = prompt }, function(input)
    if input and input:lower() == "y" then
      local ok
      if node.type == "dir" then
        ok = vim.fn.delete(node.path, "rf")
      else
        ok = vim.fn.delete(node.path)
      end

      if ok == 0 then
        tree.refresh(state)
        vim.notify("Deleted: " .. node.name, vim.log.levels.INFO)
      else
        vim.notify(
          "Failed to delete: " .. node.name,
          vim.log.levels.ERROR
        )
      end
    end
  end)
end

function M.yank_node(state)
  local render = require("multi-tree.render")
  local state_module = require("multi-tree.state")
  local node = render.get_node_under_cursor(state)
  if not node then return end

  state_module.clipboard = {
    path = node.path,
    type = node.type,
    mode = "copy",
  }
  vim.notify("Yanked: " .. node.name, vim.log.levels.INFO)
end

function M.cut_node(state)
  local render = require("multi-tree.render")
  local state_module = require("multi-tree.state")
  local node = render.get_node_under_cursor(state)
  if not node then return end

  state_module.clipboard = {
    path = node.path,
    type = node.type,
    mode = "cut",
  }
  vim.notify("Cut: " .. node.name, vim.log.levels.INFO)
end

--- Recursively copy a directory using vim.loop.
local function copy_dir(src, dest)
  vim.fn.mkdir(dest, "p")
  -- Preserve source directory permissions.
  local src_stat = uv.fs_stat(src)
  if src_stat then
    uv.fs_chmod(dest, src_stat.mode)
  end
  local iter = uv.fs_scandir(src)
  if not iter then return false end
  while true do
    local name, typ = uv.fs_scandir_next(iter)
    if not name then break end
    local s = src .. "/" .. name
    local d = dest .. "/" .. name
    local stat = uv.fs_stat(s)
    local is_dir = (typ == "directory") or
                   (stat and stat.type == "directory")
    if is_dir then
      if not copy_dir(s, d) then return false end
    elseif typ == "link" then
      local link_target = uv.fs_readlink(s)
      if not link_target or not uv.fs_symlink(link_target, d) then
        return false
      end
    else
      local ok = uv.fs_copyfile(s, d)
      if not ok then return false end
    end
  end
  return true
end

local function delete_path(path, typ)
  if typ == "dir" then
    return vim.fn.delete(path, "rf") == 0
  end
  return vim.fn.delete(path) == 0
end

local function move_path(src, dest, typ)
  if vim.fn.rename(src, dest) == 0 then
    return true
  end

  local copied
  if typ == "dir" then
    copied = copy_dir(src, dest)
  else
    copied = uv.fs_copyfile(src, dest)
  end
  if not copied then
    -- Clean up partial copy debris.
    if typ == "dir" then delete_path(dest, typ) end
    return false
  end

  if delete_path(src, typ) then
    return true
  end

  -- Best-effort rollback to avoid leaving a duplicate at destination.
  delete_path(dest, typ)
  return false
end

--- Refresh every open tree whose root is an ancestor of `path`.
local function refresh_trees_containing(path)
  local state_module = require("multi-tree.state")
  local tree = require("multi-tree.tree")
  local utils = require("multi-tree.utils")
  for _, st in pairs(state_module.states) do
    if st.root_node and st.root_node.path then
      if utils.is_subpath(path, st.root_node.path) then
        tree.refresh(st)
      end
    end
  end
end

function M.paste_node(state)
  local render = require("multi-tree.render")
  local state_module = require("multi-tree.state")
  local utils = require("multi-tree.utils")

  local clip = state_module.clipboard
  if not clip then
    vim.notify("Nothing yanked.", vim.log.levels.WARN)
    return
  end

  local node = render.get_node_under_cursor(state)
  if not node then return end

  local dest_dir = node.type == "dir" and node.path or
                   vim.fn.fnamemodify(node.path, ":h")

  local src_name = utils.basename_safe(clip.path)
  local dest_path = dest_dir .. "/" .. src_name

  local function do_paste(final_dest)
    if clip.type == "dir" then
      local src_norm = utils.normalize_path(clip.path)
      local dest_norm = utils.normalize_path(final_dest)
      if utils.is_subpath(dest_norm, src_norm) then
        vim.notify(
          "Cannot paste a directory into itself.",
          vim.log.levels.ERROR
        )
        return
      end
    end

    local ok
    local is_cut = clip.mode == "cut"
    if is_cut then
      ok = move_path(clip.path, final_dest, clip.type)
    elseif clip.type == "dir" then
      ok = copy_dir(clip.path, final_dest)
    else
      ok = uv.fs_copyfile(clip.path, final_dest)
    end
    if ok then
      local final_name = utils.basename_safe(final_dest)
      local verb = is_cut and "Moved" or "Pasted"
      vim.notify(verb .. ": " .. final_name, vim.log.levels.INFO)
      if is_cut then
        -- Clear clipboard after a move so you can't move twice.
        state_module.clipboard = nil
        -- Refresh trees that contained the source as well.
        refresh_trees_containing(clip.path)
      end
      refresh_trees_containing(final_dest)
    else
      vim.notify(
        "Failed to paste: " .. src_name,
        vim.log.levels.ERROR
      )
    end
  end

  -- Check if destination already exists.
  if uv.fs_stat(dest_path) then
    vim.ui.input({
      prompt = "'" .. src_name ..
               "' already exists. New name (blank to cancel): ",
    }, function(new_name)
      if not new_name or new_name == "" then return end
      do_paste(dest_dir .. "/" .. new_name)
    end)
  else
    do_paste(dest_path)
  end
end

function M.bookmark_add(state)
  local render = require("multi-tree.render")
  local bookmarks = require("multi-tree.bookmarks")
  local utils = require("multi-tree.utils")
  local node = render.get_node_under_cursor(state)
  if not node then return end

  local default = node.name
  vim.ui.input({
    prompt = "Bookmark label: ",
    default = default,
  }, function(label)
    if not label or label == "" then return end
    local path = utils.normalize_path(node.path)
    bookmarks.add(label, path)
    vim.notify(
      "Bookmarked '" .. label .. "' -> " .. path,
      vim.log.levels.INFO
    )
  end)
end

local function pick_bookmark(prompt, on_choice)
  local bookmarks = require("multi-tree.bookmarks")
  local entries = bookmarks.list()
  if #entries == 0 then
    vim.notify("No bookmarks set.", vim.log.levels.WARN)
    return
  end
  vim.ui.select(entries, {
    prompt = prompt,
    format_item = function(item)
      return item.label .. "  " .. item.path
    end,
  }, function(choice)
    if not choice then return end
    on_choice(choice)
  end)
end

function M.bookmark_jump()
  local multi_tree = require("multi-tree")
  pick_bookmark("Jump to bookmark:", function(choice)
    multi_tree.reveal_path(choice.path)
  end)
end

function M.bookmark_delete()
  local bookmarks = require("multi-tree.bookmarks")
  pick_bookmark("Delete bookmark:", function(choice)
    if bookmarks.remove(choice.label) then
      vim.notify(
        "Removed bookmark '" .. choice.label .. "'.",
        vim.log.levels.INFO
      )
    end
  end)
end

function M.copy_path(state, mode)
  local render = require("multi-tree.render")
  local utils = require("multi-tree.utils")
  local node = render.get_node_under_cursor(state)
  if not node then return end

  local path
  if mode == "relative" then
    if not state.root_node or not state.root_node.path then
      return
    end
    local root = utils.normalize_path(state.root_node.path)
    local abs = utils.normalize_path(node.path)
    if abs == root then
      path = "."
    elseif utils.is_subpath(abs, root) then
      path = abs:sub(#root + 2)
    else
      vim.notify(
        "Node is not under tree root.",
        vim.log.levels.WARN
      )
      return
    end
  else
    path = utils.normalize_path(node.path)
  end

  vim.fn.setreg("+", path)
  vim.fn.setreg('"', path)
  vim.notify("Copied: " .. path, vim.log.levels.INFO)
end

function M.open_in_next_tab(how, stay)
  local state_module = require("multi-tree.state")
  local render = require("multi-tree.render")
  local state = state_module.get_current()
  if not state then return end

  local node = render.get_node_under_cursor(state)
  if not node or node.type ~= "file" then return end

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

  local escaped = vim.fn.fnameescape(node.path)
  if effective == "vsplit" then
    vim.cmd("vsplit " .. escaped)
  elseif effective == "split" then
    vim.cmd("split " .. escaped)
  else
    vim.cmd("edit " .. escaped)
  end

  if state.root_node and state.root_node.path then
    vim.cmd("lcd " .. vim.fn.fnameescape(state.root_node.path))
  end

  if stay then
    local prev = vim.fn.tabpagenr("#")
    if prev ~= 0 then
      vim.cmd(("%dtabnext"):format(prev))
    end
  end
end

return M
