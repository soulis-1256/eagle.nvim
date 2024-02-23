# eagle.nvim

***To soar like an eagle is to rise above all the obstacles that come your way.***

Following your mouse cursor, this plugin introduces a custom floating (popup) window that displays any diagnostic (Error, Warning, Hint) with the help of the Diagnostic API of Neovim, along with LSP Information.
### Overview
Enhance your Neovim experience by utilizing the following features:
- Detect when the mouse hovers over an underlined part of code, including nested code and diagnostics that are in different parts of the same line.
- Process what kind of diagnostic is under the current mouse position. If there are multiple diagnostics on the same position (ie error and warning), display them all in a numbered list.
- Show LSP information (the same contents as with vim.lsp.buf.hover()).
---
You can see how the window looks in the following screenshot:
![image](https://github.com/soulis-1256/eagle.nvim/assets/118274635/6bff3e99-7327-485e-b209-6d673f801be2)

This was in a C++ workspace, with clangd and clang-tidy configured. Remember that you can also shift+click the href links to open them in your browser.

> [!NOTE]\
> The plugin has been tested on Neovim versions 0.9.4 and 0.9.5.

### Installation
Using [Lazy](https://github.com/folke/lazy.nvim):
```lua
{
    "soulis-1256/eagle.nvim"
},
```

### Setup
All the configurable options are in the "defaults" table of [config.lua](./lua/eagle/config.lua).
```lua
require("eagle").setup({})
```

---
### Support
You can support me by donating through [PayPal](https://www.paypal.com/paypalme/soulis1256) and by providing your feedback. You can find me on [Discord](https://discord.com/users/319490489411829761).
