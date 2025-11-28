local M = {}

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

function M.render(state)
  local buf = state.buf
  local config = require("multi-tree.config").get()
  local utils = require("multi-tree.utils")

  vim.bo[buf].readonly = false
  vim.bo[buf].modifiable = true

  local root = state.root_node
  local lines = {}
  local line2node = {}

  local visible = build_visible(root)
  for i, node in ipairs(visible) do
    local indent = string.rep(" ", config.indent * node.depth)
    local marker = ""
    if node.type == "dir" then
      marker = node.expanded and "▾ " or "▸ "
    else
      marker = "  "
    end
    local ico = utils.icon_for(node, "")
    lines[i] = indent .. marker .. ico .. node.name
    line2node[i] = node
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  state.line2node = line2node
end

function M.get_node_under_cursor(state)
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.line2node and state.line2node[row] or nil
end

return M
