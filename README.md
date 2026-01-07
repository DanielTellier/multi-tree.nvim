# multi-tree.nvim

View more than one tree in a tab.

## What is MultiTree

MultiTree is a lightweight Neovim plugin that lets you open multiple, independent
directory trees side-by-side within the same tab. Each tree instance is window-local,
so changing the root or expanding nodes in one window will not affect the others.
It’s inspired by the UX and architecture of nvim-tree.lua and neo-tree.nvim.

![MultiTree Plugin Demo](docs/multi-tree-demo.gif)

## Table of Contents

- [Features](#features)
- [Installation](#installation)
  - [lazy.nvim example (recommended)](#lazynvim-example-recommended)
  - [Manual installation](#manual-installation)
- [Commands](#commands)
- [Keymaps](#keymaps)
- [Default Configuration](#default-configuration)
- [Configuration](#configuration)
- [Window-local CWD](#window-local-cwd)
- [Custom mappings](#custom-mappings)
- [Troubleshooting](#troubleshooting)
- [Acknowledgements](#acknowledgements)
- [Contributing](#contributing)
- [License](#license)

## Features

- Per-window tree instances with independent roots and expansion state.
- Window-local working directory (pwd) per tree window, with optional restore on close.
- Directory-first sorting with optional hidden files filtering.
- Optional icons via nvim-web-devicons.
- Simple, buffer-local keymaps for expand/collapse and opening files.
- "Open in next tab" actions (edit/split/vsplit), with "stay in tree" variants.
- Commands to open, refresh, and close trees.

## Installation

### lazy.nvim example (recommended)

```lua
{
  "DanielTellier/multi-tree.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
},
```

### Manual installation

- Place plugin file at: `~/.config/nvim/plugin/multi-tree.lua`
- Place module files in: `~/.config/nvim/lua/multi-tree/`
- Restart Neovim

## Commands

- `:MultiTree [path].` Open a tree in the current window. Defaults to the current working directory if no path is given.
- `:MultiTreeRefresh.` Rescan the current tree and refresh its contents.
- `:MultiTreeClose.` Close the current tree buffer.

## Keymaps

Inside a MultiTree buffer:

- Enter: Toggle a directory or open a file. The plugin attempts to open files in the
  previously focused window and sets that window’s local cwd to the tree’s root if enabled.
- l: Expand a directory or open a file.
- h: Collapse a directory or collapse its parent.
- v: Open a file in a vertical split (sets local cwd if enabled).
- s: Open a file in a horizontal split (sets local cwd if enabled).
- t: Open a file in a new tab (sets local cwd if enabled).
- C: Change the root to the selected directory (updates local cwd if enabled).
- r: Refresh the tree.
- q: Close the tree buffer.

Netrw-style file operations:

- s: Toggle sort mode between name and modification time.
- %: Create new file in current/selected directory.
- d: Create new directory in current/selected directory.
- R: Rename file or directory under cursor.
- D: Delete file or directory under cursor (with confirmation).

Optional “open in next tab” actions (enabled when `map_next_tab_keys = true`):

- <leader>i: Open file on next tab.
- <leader>I: Open file on next tab and stay in tree.
- <leader>o: Open file in horizontal split on next tab.
- <leader>O: Open file in horizontal split on next tab and stay in tree.
- <leader>v: Open file in vertical split on next tab.
- <leader>V: Open file in vertical split on next tab and stay in tree.

To customize or disable these, see the “Custom mappings” section.

## Default Configuration

The plugin comes with sensible defaults that work out of the box.
Here are all the available options and their default values:

```lua
{
  icons = true,                 -- Enable icons via nvim-web-devicons if available
  show_hidden = false,          -- Show dotfiles and hidden files when true
  indent = 2,                   -- Indentation size for tree levels (spaces)
  set_local_cwd = true,         -- Set window-local working directory (:lcd) to tree root
  restore_local_cwd_on_close = false, -- Restore previous cwd when closing tree buffer
  map_next_tab_keys = true,     -- Provide default <leader> mappings for "open in next tab"
}
```

## Configuration

Call setup to adjust defaults:

```lua
require("multi-tree").setup({
  icons = true,                 -- Enable icons via nvim-web-devicons if available.
  show_hidden = false,          -- Show dotfiles when true.
  indent = 2,                   -- Indentation size for tree levels.
  set_local_cwd = true,         -- Set :lcd to the tree’s root for the tree window.
  restore_local_cwd_on_close = false, -- Restore previous cwd when closing the tree buffer.
  map_next_tab_keys = true,     -- Provide default <leader>{i,I,o,O,v,V} mappings.
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

## Window-local CWD

By default, MultiTree sets a window-local working directory (`:lcd`) equal to the
tree’s root for the tree window:

- When you change the tree’s root, the window-local cwd updates accordingly.
- When opening files (Enter, split, vsplit, tab, or “open in next tab”), the target
  window’s local cwd is set to the tree’s root first.
- To disable this behavior, set `set_local_cwd = false`.
- To restore the previous cwd when the tree buffer closes, set `restore_local_cwd_on_close = true`.

If you prefer per-tab rather than per-window cwd, use `:tcd` in your own fork or local patch.

## Custom mappings

Disable the default “open in next tab” mappings and define your own:

```lua
-- Disable built-in next-tab mappings.
require("multi-tree").setup({
  map_next_tab_keys = false,
})

-- Add custom mappings for MultiTree buffers.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "multi-tree",
  callback = function(ev)
    local buf = ev.buf
    -- Examples:
    vim.keymap.set("n", "<leader>i", function()
      require("multi-tree").open_current_node_in_next_tab("edit", false)
    end, { buffer = buf, desc = "Open file on next tab" })

    vim.keymap.set("n", "<leader>I", function()
      require("multi-tree").open_current_node_in_next_tab("edit", true)
    end, { buffer = buf, desc = "Open file on next tab and stay" })

    vim.keymap.set("n", "<leader>o", function()
      require("multi-tree").open_current_node_in_next_tab("split", false)
    end, { buffer = buf, desc = "Open split on next tab" })

    vim.keymap.set("n", "<leader>O", function()
      require("multi-tree").open_current_node_in_next_tab("split", true)
    end, { buffer = buf, desc = "Open split on next tab and stay" })

    vim.keymap.set("n", "<leader>v", function()
      require("multi-tree").open_current_node_in_next_tab("vsplit", false)
    end, { buffer = buf, desc = "Open vsplit on next tab" })

    vim.keymap.set("n", "<leader>V", function()
      require("multi-tree").open_current_node_in_next_tab("vsplit", true)
    end, { buffer = buf, desc = "Open vsplit on next tab and stay" })
  end,
})
```

Create mappings to open MultiTree in various window types:

```lua
local wk = require("which-key")

wk.add({
  { "<leader>z", group = "multi-tree", mode = "n" }
})

vim.keymap.set(
  "n", "<leader>zz", "<cmd>MultiTree<cr>",
  { noremap = true, silent = true, desc = "Open multi-tree given cwd" }
)
vim.keymap.set(
  "n", "<leader>ze", ":MultiTree ",
  { noremap = true, silent = false, desc = "Open multi-tree in the current window with a provided path" }
)
vim.keymap.set(
  "n", "<leader>zv", ":vs | MultiTree ",
  { noremap = true, silent = false, desc = "Open multi-tree in a vertical split with a provided path" }
)
vim.keymap.set(
  "n", "<leader>zo", ":sp | MultiTree ",
  { noremap = true, silent = false, desc = "Open multi-tree in a horizontal split with a provided path" }
)
```

## Troubleshooting

- “W10: Warning: Changing a readonly file.” MultiTree sets tree buffers modifiable
  only during rendering. Ensure the tree buffer is not set to `readonly = true`.
- PWD not applied. Ensure `set_local_cwd = true`. For “open in next tab,” MultiTree
  sets the local cwd in the destination tab’s window before opening.

## Acknowledgements

- Inspired by [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua), [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim), and [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- Optional icons via [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons).

## Contributing

Issues and pull requests are welcome. Please open issues for bugs, performance problems,
or UX improvements, and include steps to reproduce when possible.

## License

MIT. See the repository for details: [DanielTellier/multi-tree.nvim](https://github.com/DanielTellier/multi-tree.nvim).
