# multi-tree.nvim

MultiTree is a lightweight Neovim plugin that lets you open multiple, independent directory trees side-by-side within the same tab. Each tree instance is window-local, so changing the root or expanding nodes in one window will not affect the others. It’s inspired by the UX and architecture of nvim-tree.lua and neo-tree.nvim.

## Features

- Per-window tree instances with independent roots and expansion state.
- Directory-first sorting with optional hidden files filtering.
- Optional icons via nvim-web-devicons.
- Simple, buffer-local keymaps for expand/collapse and opening files.
- Commands to open, refresh, close trees, and rename tab titles.
- Optional tab titles integration with Heirline.

## Installation

### lazy.nvim example (recommended)

```lua
{
  "DanielTellier/multi-tree.nvim",
  event = "VeryLazy", -- or lazy = false if you want it at startup
  main = "multi-tree",
  dependencies = {
    "nvim-tree/nvim-web-devicons", -- optional, for file icons
    -- Optional: integrate tab titles using heirline.
    {
      "rebelot/heirline.nvim",
      config = function()
        local function mt_label_for_tab(tab)
          local ok, mt = pcall(require, "multi-tree")
          if ok and mt.tab_title then
            return mt.tab_title(tab)
          end
          local win = vim.api.nvim_tabpage_get_win(tab)
          local buf = vim.api.nvim_win_get_buf(win)
          local name = vim.api.nvim_buf_get_name(buf)
          return (name ~= "" and vim.fn.fnamemodify(name, ":t")) or "[No Name]"
        end

        require("heirline").setup({
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
      end,
    },
  },
  opts = {
    icons = true,        -- Set false to avoid devicons dependency.
    show_hidden = false, -- Set true to show dotfiles.
    indent = 2,
  },
  keys = {
    {
      "<leader>et",
      function()
        require("multi-tree").open(vim.loop.cwd())
      end, desc = "Open MultiTree at CWD"
    },
    {
      "<leader>eT",
      function()
        require("multi-tree").open(vim.fn.expand("%:p:h"))
      end, desc = "Open MultiTree at file dir"
    },
  },
}
```

### Manual installation

- Place plugin file at: ~/.config/nvim/plugin/multi-tree.lua.
- Place module file at: ~/.config/nvim/lua/multi-tree/init.lua.
- Restart Neovim.

## Post-install: Try it out

- Open a tree in the current window: `:MultiTree`.
- Open a tree rooted at a specific directory: `:MultiTree /path/to/dir`.
- Open multiple trees side-by-side in one tab:
  - `:vsplit | :MultiTree ~/projects/A`.
  - `Ctrl-w l | :vsplit | :MultiTree ~/projects/B`.

## Commands

- `:MultiTree [path].` Open a tree in the current window. Defaults to the current working directory if no path is given.
- `:MultiTreeRefresh.` Rescan the current tree and refresh its contents.
- `:MultiTreeClose.` Close the current tree buffer.
- `:MultiTreeTabRename <name>.` Rename the current tab’s title (for Heirline or custom tabline integrations).

## Keymaps

Inside a MultiTree buffer:

- Enter: Toggle a directory or open a file. The plugin attempts to open files in the previously focused window to keep the tree visible.
- l: Expand a directory or open a file.
- h: Collapse a directory or collapse its parent.
- v: Open a file in a vertical split.
- s: Open a file in a horizontal split.
- t: Open a file in a new tab.
- C: Change the root to the selected directory.
- r: Refresh the tree.
- q: Close the tree buffer.

## Configuration

Call setup to adjust defaults:

```lua
require("multi-tree").setup({
  icons = true,        -- Enable icons via nvim-web-devicons if available.
  show_hidden = false, -- Show dotfiles when true.
  indent = 2,          -- Indentation size for tree levels.
})
```

Make tree windows clean and fixed-width:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "multi-tree",
  callback = function()
    vim.opt_local.winfixwidth = true
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
  end,
})
```

Optional: control whether the tree buffer is “listed” in Neovim’s buffer list. Unlisted buffers won’t appear in `:ls`, won’t be cycled by `:bnext/:bprev`, and are typically hidden by bufferline plugins. This is recommended for explorer sidebars.

## Heirline Tab Titles

MultiTree can provide per-tab titles and a small API for Heirline:

- The plugin tracks a title for tabs where a tree is opened for the first time, like “MultiTree-1,” “MultiTree-2,” etc.
- Heirline can call `require("multi-tree").tab_title(tab)` to render these titles. If no title is set, it falls back to the active buffer’s name in that tab.
- Rename the current tab’s title with `:MultiTreeTabRename <name>.`

See the lazy.nvim example above for an integrated Heirline configuration.

## Tips

- Open files from a tree in another window: focus the target window once (for example, `Ctrl-w p`), then press Enter on a file in the tree.
- Keep trees independent: each tree buffer is window-local. Changing the root or expanding nodes in one tree does not affect other trees.
- Use absolute paths or robust path expansions for consistent root labeling. Paths with trailing slashes are normalized internally.

## Troubleshooting

- “W10: Warning: Changing a readonly file.” MultiTree sets tree buffers modifiable only during rendering. Ensure the tree buffer is not set to `readonly = true`.
- Root name missing with trailing slash (for example, `:MultiTree lua/`). Paths are normalized to strip trailing separators, and the root label is derived safely; update to the latest version if this ever occurs.
- Tabline conflicts. Only one thing should set `vim.o.tabline`. If you use a tabline plugin such as Heirline, do not let MultiTree set `vim.o.tabline`; integrate titles through the plugin’s config.

## Acknowledgements

- Inspired by [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua) and [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim).
- Optional icons via [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons).
- Optional tabline integration via [heirline.nvim](https://github.com/rebelot/heirline.nvim).

## Contributing

Issues and pull requests are welcome. Please open issues for bugs, performance problems, or UX improvements, and include steps to reproduce when possible.

## License

MIT. See the repository for details: [DanielTellier/multi-tree.nvim](https://github.com/DanielTellier/multi-tree.nvim).
