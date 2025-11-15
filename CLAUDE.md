# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-tree.nvim is a lightweight Neovim plugin that enables multiple, independent directory tree instances side-by-side within the same tab. Each tree is window-local - changes in one tree (root changes, expanded nodes) don't affect others.

## Core Architecture

### Single-Module Design

The plugin follows a simple architecture with two main files:

- `plugin/multi-tree.lua` - Entry point, command registration, autocmd setup
- `lua/multi-tree/init.lua` - Core implementation (~765 lines)

### State Management

The plugin uses a state-based architecture where each tree buffer has its own state object stored in `M.states` (hash table mapping buffer IDs to states). Each state contains:

```lua
{
  win = window_id,
  buf = buffer_id,
  root_node = node_tree,
  opts = merged_config,
  line2node = {}, -- maps line numbers to node objects
  previous_cwd = path -- for restore on close
}
```

### Tree Data Structure

Nodes are represented as:

```lua
{
  path = "/absolute/path",
  name = "filename",
  type = "dir" | "file",
  children = nil | {nodes...}, -- nil = not loaded, table = loaded
  expanded = boolean,
  depth = number,
  mtime = timestamp
}
```

Key implementation detail: children are loaded lazily when directories are expanded, not all at once.

### Rendering Pipeline

1. `build_visible()` - Traverse tree respecting `expanded` state to build flat list
2. `render()` - Convert flat list to lines with indentation and markers (▾/▸)
3. Maintain `line2node` mapping for efficient cursor-to-node lookup

## Development Commands

### No Build System

This plugin has no build system, test framework, or linting configuration. It's distributed as raw Lua source code and installed directly via Neovim plugin managers.

### Testing During Development

Since there are no automated tests:

1. **Local development**: Add to your Neovim config via lazy.nvim with local path:
   ```lua
   { dir = "/path/to/multi-tree.nvim", main = "multi-tree", opts = {} }
   ```

2. **Reload changes**: Use `:luafile %` when editing the plugin file, or restart Neovim

3. **Debug output**: Use `:messages` to view `vim.notify()` calls in the code

4. **Inspect state**:
   ```vim
   :lua print(vim.inspect(require('multi-tree').states))
   ```

## Key Implementation Patterns

### Uniqueness Enforcement

`find_existing_tree_for_path()` ensures only one tree per directory exists. If a tree for that path is already open, it focuses the existing window instead of creating a duplicate.

### Path Normalization

All paths go through `normalize_path()` early to handle cross-platform differences and trailing slashes. This is critical for uniqueness checking and display.

### Window-Local CWD Management

The plugin uses `:lcd` (window-local cwd) to keep each tree independent. When `set_local_cwd = true`:
- Tree window's cwd is set to the tree root
- Target windows get their cwd set before opening files
- Optional restoration on close with `restore_local_cwd_on_close`

### Buffer-Local Keymaps

All keymaps are buffer-local using `{ buffer = buf }`, preventing conflicts with other buffers. Mappings are attached in `attach_mappings()` when the buffer is created.

### Scratch Buffer Pattern

Trees use standard Neovim scratch buffer settings:
```lua
buftype = "nofile"
bufhidden = "wipe"
swapfile = false
```

Cleanup happens via `BufWipeout` and `BufUnload` autocmds that remove state from `M.states`.

### Defensive Programming

The code uses `pcall()` extensively for optional features (devicons, tab operations) and gracefully degrades when dependencies are missing.

## Module Organization

The main module (`lua/multi-tree/init.lua`) is organized into logical sections:

1. **State & Config** - `M.states`, `M.config`, `M.tab_titles`
2. **Utilities** - Path handling, basename extraction, icon lookup
3. **Tree Operations** - scandir, load_children, build_visible, render
4. **User Actions** - toggle, change_root, open_file, file operations
5. **API Functions** - setup, open, refresh, close, tab_rename
6. **Tab Title Integration** - Heirline API functions

## File Operation Functions

Netrw-style operations implemented:
- `create_file()` - Prompt for path, create file
- `create_directory()` - Prompt for path, create directory
- `rename_file()` - Prompt for new name, rename via `vim.loop.fs_rename`
- `delete_file()` - Confirm, then delete via `vim.loop.fs_unlink` or `vim.loop.fs_rmdir`

All operations refresh the tree after completion.

## Session Persistence

The plugin doesn't automatically persist state. If implementing session support:

1. Save `vim.g.multi_tree_session` on `VimLeavePre` with roots_by_tab structure
2. Restore on `SessionLoadPost` by calling `require('multi-tree').open(path)` for each saved root
3. The README documents this pattern in detail

## Recent Refactoring

Recent commits removed:
- Bookmark functionality
- "Go up directory" functionality
- Directory history functionality

Focus has shifted toward simplification and core features only.

## Optional Dependencies

- `nvim-web-devicons` - For file icons (`icons` config option)
- `heirline.nvim` - For tab title integration (`tab_title()` API function)

Both are gracefully optional - the plugin works without them.

## Common Modification Points

When extending the plugin:

- **Add keymaps**: Modify `attach_mappings()` function
- **Add node actions**: Follow pattern of existing action functions (open_file, toggle, etc.)
- **Modify rendering**: Update `render()` function for visual changes
- **Add config options**: Add to `M.config` defaults and merge in `setup()`
- **Add file operations**: Follow pattern in create_file/rename_file/delete_file

## Code Style

- Use `local function` for internal functions within the module
- Use `M.function_name` for public API functions
- Prefer early returns for guard clauses
- Use descriptive variable names (no single-letter except loop indices)
- pcall for optional features, with fallback behavior
