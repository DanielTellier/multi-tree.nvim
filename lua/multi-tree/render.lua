local M = {}

local ns = vim.api.nvim_create_namespace("multi_tree")

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

local function name_hl(node)
  if node.type == "dir" then return "MultiTreeDir" end
  if node.name:sub(1, 1) == "." then return "MultiTreeHidden" end
  return "MultiTreeFile"
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
  local segments = {}

  local visible = build_visible(root)
  for i, node in ipairs(visible) do
    local indent = string.rep(" ", config.indent * node.depth)
    local marker
    if node.type == "dir" then
      marker = node.expanded and "▾ " or "▸ "
    else
      marker = "  "
    end
    local ico = utils.icon_for(node, "")
    local line = indent .. marker .. ico .. node.name
    lines[i] = line
    line2node[i] = node

    local marker_start = #indent
    local marker_end = marker_start + #marker
    local icon_end = marker_end + #ico
    local name_end = #line
    segments[i] = {
      marker_s = marker_start,
      marker_e = marker_end,
      icon_s = marker_end,
      icon_e = icon_end,
      name_s = icon_end,
      name_e = name_end,
      is_root = node.depth == 0,
      name_hl = name_hl(node),
    }
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  for i, seg in ipairs(segments) do
    local row = i - 1
    if seg.is_root then
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        end_row = row,
        end_col = #lines[i],
        hl_group = "MultiTreeRoot",
      })
    else
      if seg.marker_e > seg.marker_s then
        vim.api.nvim_buf_set_extmark(buf, ns, row, seg.marker_s, {
          end_col = seg.marker_e,
          hl_group = "MultiTreeMarker",
        })
      end
      if seg.icon_e > seg.icon_s then
        vim.api.nvim_buf_set_extmark(buf, ns, row, seg.icon_s, {
          end_col = seg.icon_e,
          hl_group = "MultiTreeIcon",
        })
      end
      if seg.name_e > seg.name_s then
        vim.api.nvim_buf_set_extmark(buf, ns, row, seg.name_s, {
          end_col = seg.name_e,
          hl_group = seg.name_hl,
        })
      end
    end
  end

  vim.bo[buf].modifiable = false

  state.line2node = line2node
end

function M.get_node_under_cursor(state)
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.line2node and state.line2node[row] or nil
end

return M
