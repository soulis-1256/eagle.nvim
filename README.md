# 🦅 eagle.nvim

[![Neovim](https://img.shields.io/badge/Neovim-0.10.2+-57A143?style=flat-square&logo=neovim&logoColor=white)](https://neovim.io)
[![License](https://img.shields.io/github/license/soulis-1256/eagle.nvim?style=flat-square)](./LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/soulis-1256/eagle.nvim?style=flat-square)](https://github.com/soulis-1256/eagle.nvim/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/soulis-1256/eagle.nvim?style=flat-square)](https://github.com/soulis-1256/eagle.nvim/commits/main)

A Neovim plugin that provides a floating window for diagnostics and LSP information.

![showcase_eagle](https://github.com/soulis-1256/eagle.nvim/assets/118274635/ec28d139-0087-4e0d-a52b-c217231b846e)

## Table of Contents

- [Features](#-features)
- [Why eagle.nvim?](#-why-eaglenvim)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [Support](#-support)
- [Acknowledgments](#-acknowledgments)

## Features

- **Smart Mouse Tracking** — Detects when the mouse hovers over underlined code. Once idle (configurable delay), a floating window appears, mirroring the behavior of conventional GUI editors like VS Code.

- **Comprehensive Diagnostics** — Displays all diagnostics (Errors, Warnings, Hints) under the current position. Multiple diagnostics at the same location are shown in a numbered list.

- **LSP Integration** — Shows LSP hover information (same content as `vim.lsp.buf.hover()`).

- **Intelligent Re-rendering** — The window only re-renders when the mouse encounters a "special" character (like `{}.?:`), staying open while hovering over the same variable/function/operator name.

- **Keyboard Mode** — Opt-in keyboard control that can work alongside or independently of mouse control (eg. using the `<Tab>` key).

- **Highly Customizable** — Extensive configuration options for appearance, timing, and behavior.

## Why eagle.nvim?

| Feature | Built-in `vim.diagnostic.open_float()` | Built-in `vim.lsp.buf.hover()` | eagle.nvim |
|---------|:--------------------------------------:|:------------------------------:|:----------:|
| Mouse tracking | ❌ | ❌ | ✅ |
| Combined diagnostics + LSP | ❌ | ❌ | ✅ |
| Smart rendering | ❌ | ❌ | ✅ |
| Keyboard + Mouse cooperation | ❌ | ❌ | ✅ |

## Requirements

- Neovim `>= 0.10.2` (API level 12)
- A configured LSP server to provide the LSP information

## Installation

<details>
<summary><b>Using lazy.nvim</b></summary>

[lazy.nvim](https://github.com/folke/lazy.nvim) is a modern plugin manager for Neovim.

**Basic setup:**
```lua
{
    "soulis-1256/eagle.nvim",
    opts = {},
    config = function(_, opts)
        require("eagle").setup(opts)
        vim.o.mousemoveevent = true -- Required for mouse mode
    end,
},
```

**With keyboard mode enabled:**
```lua
{
    "soulis-1256/eagle.nvim",
    opts = {
        keyboard_mode = true,
    },
    config = function(_, opts)
        require("eagle").setup(opts)
        vim.o.mousemoveevent = true
        vim.keymap.set('n', '<Tab>', ':EagleWin<CR>', { noremap = true, silent = true })
    end,
},
```

**Alternative setup (if you encounter issues with `opts`):**
```lua
{ "soulis-1256/eagle.nvim" },
```
Then in your config:
```lua
require("eagle").setup({
    -- your options here
})
vim.o.mousemoveevent = true
```
</details>

<details>
<summary><b>Using LazyVim</b></summary>

[LazyVim](https://www.lazyvim.org/) is a Neovim setup powered by lazy.nvim.

Create a file under `lua/plugins/eagle.lua`:
```lua
return {
    {
        "soulis-1256/eagle.nvim",
        config = function()
            require("eagle").setup({
                keyboard_mode = true,
            })
            vim.o.mousemoveevent = true
            vim.keymap.set('n', '<Tab>', ':EagleWin<CR>', { noremap = true, silent = true })
        end,
    },
}
```
</details>

## Configuration

All options can be passed to the `setup()` function. See [config.lua](./lua/eagle/config.lua) for extensive documentation.

### Default Options

```lua
require("eagle").setup({
    -- Behavior
    mouse_mode = true,           -- Enable mouse hover detection
    keyboard_mode = false,       -- Enable keyboard-triggered window
    close_on_cmd = true,         -- Close window when entering command mode
    show_lsp_info = true,        -- Show LSP hover information
    logging = false,             -- Enable debug logging

    -- Content
    show_headers = true,         -- Show section headers in the window
    order = 1,                   -- Order of content (1: diagnostics first, 2: LSP first)
    improved_markdown = true,    -- Enhanced markdown rendering

    -- Timing
    render_delay = 500,          -- Delay (ms) before rendering the window
    detect_idle_timer = 50,      -- Interval (ms) for idle detection

    -- Window Positioning
    window_row = 1,              -- Vertical offset from cursor
    window_col = 5,              -- Horizontal offset from cursor
    scrollbar_offset = 0,        -- Offset for scrollbar

    -- Window Size
    max_width_factor = 2,        -- Max width as factor of window width
    max_height_factor = 2.5,     -- Max height as factor of window height

    -- Window Appearance
    border = "single",           -- Border style: "single", "double", "rounded", "solid", "shadow", "none"
    title = "",                  -- Window title
    title_pos = "center",        -- Title position: "left", "center", "right"

    -- Colors (leave empty to use defaults)
    title_color = "#8AAAE5",           -- Title text color
    border_color = "#8AAAE5",          -- Border color
    diagnostic_header_color = "",      -- Diagnostic header color
    lsp_info_header_color = "",        -- LSP info header color
    diagnostic_content_color = "",     -- Diagnostic content color
    lsp_info_content_color = "",       -- LSP info content color
})
```

## Usage

### Mouse Mode

1. Hover your mouse over any code with diagnostics or LSP information
2. Keep the mouse idle for the configured delay
3. The floating window will appear automatically
4. Move to a different symbol to update the window, move away to close it, or move inside it to be able to scroll through and copy its contents

### Keyboard Mode (assuming `<Tab>` is your custom keybind)

1. Position your cursor on any code with diagnostics or LSP information
2. Press `<Tab>` and the floating window will appear at your cursor position
3. Either move away to immediately close the window (eg. pressing `<h>,<j>,<k>,<l>`), or press `<Tab>` again to enter it
4. Press `<Tab>` one last time to close it (once inside)

### Commands

| Command | Description |
|---------|-------------|
| `:EagleWin` | Toggle the eagle window at the current cursor position |

## Troubleshooting

<details>
<summary><b>Window doesn't appear when hovering with mouse</b></summary>

Make sure `mousemoveevent` is enabled:
```lua
vim.o.mousemoveevent = true
```
This must be set for mouse tracking to work.
</details>

<details>
<summary><b>Window doesn't appear in keyboard mode</b></summary>

1. Ensure `keyboard_mode = true` in your setup
2. Make sure you've set a keymap for `:EagleWin`:
```lua
vim.keymap.set('n', '<Tab>', ':EagleWin<CR>', { noremap = true, silent = true })
```
</details>

<details>
<summary><b>No LSP information showing</b></summary>

1. Ensure `show_lsp_info = true` (default)
2. Verify your LSP server is attached: `:LspInfo`
3. Check if the LSP supports hover: try `:lua vim.lsp.buf.hover()`
</details>

<details>
<summary><b>Conflicts with other hover plugins</b></summary>

If you're using other plugins that provide hover functionality (like `noice.nvim` or custom LSP handlers), you may need to disable their hover features or configure them to not conflict with eagle.nvim.
</details>

<details>
<summary><b>Enable debug logging</b></summary>

To diagnose issues, enable logging:
```lua
require("eagle").setup({
    logging = true,
})
```
</details>

## Contributing

Contributions are welcome! Here's how you can help:

1. **Report bugs** — Open an issue with reproduction steps
2. **Suggest features** — Open an issue describing the feature
3. **Submit PRs** — Fork the repo, make your changes, and submit a pull request

## Support

If you find this plugin useful, consider supporting its development:

- **Star this repository** — It helps others discover the plugin
- **Provide feedback** — Your input helps improve the plugin
- **Donate** — [PayPal](https://www.paypal.com/paypalme/soulis1256)
- **Contact** — [Discord](https://discord.com/users/319490489411829761)

## Acknowledgments

- Inspired by the hover behavior of modern IDEs like VS Code
- Built on Neovim's powerful [Diagnostic API](https://neovim.io/doc/user/diagnostic.html) and [LSP API](https://neovim.io/doc/user/lsp.html)
- Thanks to all contributors and users who provide valuable feedback

<p align="center">
  Made with ❤️ for the Neovim community
</p>
