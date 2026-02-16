local M = {}

function M.attach(state)
  local buf = state.buf
  local render = require("multi-tree.render")
  local tree = require("multi-tree.tree")
  local actions = require("multi-tree.actions")
  local multi_tree = require("multi-tree")

  local function nmap(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, {
      buffer = buf,
      nowait = true,
      silent = true,
      desc = desc
    })
  end

  nmap("<CR>", function()
    local node = render.get_node_under_cursor(state)
    if not node then return end
    if node.type == "dir" then
      tree.toggle(node, state)
    else
      tree.open_file(node, "edit")
    end
  end, "Open file or toggle directory.")

  nmap("l", function()
    local node = render.get_node_under_cursor(state)
    if not node then return end
    if node.type == "dir" then
      if not node.expanded then
        tree.toggle(node, state)
      end
    else
      tree.open_file(node, "edit")
    end
  end, "Expand directory or open file.")

  nmap("h", function()
    local node = render.get_node_under_cursor(state)
    if not node then return end
    if node.type == "dir" and node.expanded then
      tree.toggle(node, state)
    else
      local row = vim.api.nvim_win_get_cursor(state.win)[1]
      local cur = state.line2node[row]
      for i = row - 1, 1, -1 do
        local candidate = state.line2node[i]
        if candidate and candidate.type == "dir" and
           candidate.depth == (cur.depth - 1) then
          candidate.expanded = false
          render.render(state)
          break
        end
      end
    end
  end, "Collapse directory.")

  nmap("o", function()
    local node = render.get_node_under_cursor(state)
    if node and node.type == "file" then
      tree.open_file(node, "split")
    end
  end, "Open file in horizontal split.")

  nmap("v", function()
    local node = render.get_node_under_cursor(state)
    if node and node.type == "file" then
      tree.open_file(node, "vsplit")
    end
  end, "Open file in vertical split.")

  nmap("t", function()
    local node = render.get_node_under_cursor(state)
    if node and node.type == "file" then
      tree.open_file(node, "tab")
    end
  end, "Open file in new tab.")

  nmap("C", function()
    local node = render.get_node_under_cursor(state)
    if node then tree.change_root(node, state) end
  end, "Change root to selected directory.")

  nmap("r", function()
    tree.refresh(state)
  end, "Refresh tree.")

  nmap("q", function()
    multi_tree.close(state)
  end, "Close tree buffer.")

  nmap("s", function()
    actions.toggle_sort(state)
  end, "Toggle sort mode.")

  nmap("%", function()
    actions.create_file(state)
  end, "Create new file.")

  nmap("d", function()
    actions.create_directory(state)
  end, "Create new directory.")

  nmap("R", function()
    actions.rename_file(state)
  end, "Rename file/directory.")

  nmap("D", function()
    actions.delete_file(state)
  end, "Delete file/directory.")

  if state.opts.map_next_tab_keys then
    nmap("<leader>i", function()
      actions.open_in_next_tab("edit", false)
    end, "Open file on next tab.")

    nmap("<leader>I", function()
      actions.open_in_next_tab("edit", true)
    end, "Open file on next tab and stay in tree.")

    nmap("<leader>o", function()
      actions.open_in_next_tab("split", false)
    end, "Open file in horizontal split on next tab.")

    nmap("<leader>O", function()
      actions.open_in_next_tab("split", true)
    end, "Open file in horizontal split on next tab and stay.")

    nmap("<leader>v", function()
      actions.open_in_next_tab("vsplit", false)
    end, "Open file in vertical split on next tab.")

    nmap("<leader>V", function()
      actions.open_in_next_tab("vsplit", true)
    end, "Open file in vertical split on next tab and stay.")
  end
end

return M
