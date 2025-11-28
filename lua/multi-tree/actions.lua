local M = {}

function M.toggle_sort(state)
  local tree = require("multi-tree.tree")
  state.sort_mode = state.sort_mode == "name" and
                    "modified" or "name"
  tree.refresh(state)
  local msg = "Sort: " ..
              (state.sort_mode == "name" and "Name" or "Modified")
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

  if state.root_node and state.root_node.path then
    vim.cmd("lcd " .. vim.fn.fnameescape(state.root_node.path))
  end

  local escaped = vim.fn.fnameescape(node.path)
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

return M
