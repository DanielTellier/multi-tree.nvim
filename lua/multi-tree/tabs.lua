local M = {}

M.tab_titles = M.tab_titles or {}
M._tab_counter = M._tab_counter or 0

function M.setup_heirline()
  local ok, heirline = pcall(require, "heirline")
  if not ok then
    return
  end

  -- Heirline tabline that uses MultiTree's per-tab titles when available.
  local function mt_label_for_tab(tab)
    local title = M.tab_titles[tab]
    if title then return title end

    -- Fallback when no multi-tree title is set.
    local win = vim.api.nvim_tabpage_get_win(tab)
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    return (name ~= "" and vim.fn.fnamemodify(name, ":t")) or "[No Name]"
  end

  heirline.setup({
    tabline = {
      {
        init = function(self)
          self.tabs = vim.api.nvim_list_tabpages()
        end,
        provider = function(self)
          local s, current = "", vim.api.nvim_get_current_tabpage()
          for _, tab in ipairs(self.tabs) do
            local nr = vim.api.nvim_tabpage_get_number(tab)
            s = s .. "%" .. nr .. "T"
            s = s .. (tab == current and "%#TabLineSel#" or "%#TabLine#")
            s = s .. " " .. mt_label_for_tab(tab) .. " "
          end
          return s .. "%#TabLineFill#%="
        end,
      },
    },
  })
end

function M.get_title(tab)
  local title = M.tab_titles[tab]
  if title then return title end

  local win = vim.api.nvim_tabpage_get_win(tab)
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  return (name ~= "" and vim.fn.fnamemodify(name, ":t")) or
         "[No Name]"
end

function M.ensure_title()
  local tab = vim.api.nvim_get_current_tabpage()
  if not M.tab_titles[tab] then
    M._tab_counter = M._tab_counter + 1
    M.tab_titles[tab] = string.format(
      "MultiTree-%d",
      M._tab_counter
    )
    vim.cmd("redrawtabline")
  end
end

function M.rename(new_name)
  if not new_name or new_name == "" then return end
  local tab = vim.api.nvim_get_current_tabpage()
  M.tab_titles[tab] = new_name
  vim.cmd("redrawtabline")
end

function M.on_closed(tabnr)
  for tab, _ in pairs(M.tab_titles) do
    local ok, nr = pcall(vim.api.nvim_tabpage_get_number, tab)
    if not ok or nr == tabnr then
      M.tab_titles[tab] = nil
    end
  end
end

function M.cleanup()
  M.tab_titles = {}
  M._tab_counter = 0
end

return M
