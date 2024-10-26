# eagle.nvim

***To soar like an eagle is to rise above all the obstacles that come your way.***

> [!IMPORTANT]\
> - [ ] Added keymap support for the eagle window
> - [ ] Rework the code to support new features regarding keyboard workflow

Following your mouse cursor, this plugin introduces a custom floating (popup) window that displays any Diagnostic (Error, Warning, Hint) with the help of the Diagnostic API of Neovim, along with LSP Information, from the LSP API.
### Overview
Enhance your Neovim experience by utilizing the following features:
- Detect when the mouse hovers over an underlined part of code. Once it goes idle (for a [configurable](./lua/eagle/config.lua) amount of time), the window will be invoked. I tried to mirror the way conventional GUI Editors like VS Code work.
- Display the Diagnostics under the current mouse position. If there are multiple diagnostics on the same position (ie Error and Warning), display them all in a numbered list. For better user experience, the window is re-rendered only once the mouse encounters a "special" character (like "{}.?:" and more). This means that it stays open if it detects mouse movement and you are still hovering over the same variable/function/operator name.
- Show LSP information (the same contents as with vim.lsp.buf.hover()).

![showcase_eagle](https://github.com/soulis-1256/eagle.nvim/assets/118274635/ec28d139-0087-4e0d-a52b-c217231b846e)
This was a C++ workspace, with clangd and clang-tidy configured. You can also shift+click the href links to open them in your browser.

### Installation
Using [Lazy](https://github.com/folke/lazy.nvim):
```lua
{
    "soulis-1256/eagle.nvim"
},
```
> [!IMPORTANT]\
> Until I test it and add it here, don't try setting additional Lazy properties (like main, config, opts) as an alternative way to setup the plugin.

### Setup
```lua
require("eagle").setup({
-- override the default values found in config.lua
})

-- make sure mousemoveevent is enabled
vim.o.mousemoveevent = true
```
You can find the description of all the options in [config.lua](./lua/eagle/config.lua).

![image](https://github.com/soulis-1256/eagle.nvim/assets/118274635/9e41fac5-7d16-4dbe-9093-0059160cf14c)

> [!NOTE]\
> The plugin has been tested on Neovim versions 0.9.4, 0.9.5 and 0.10.0

### Support
You can support me by donating through [PayPal](https://www.paypal.com/paypalme/soulis1256) and by providing your feedback. You can message me on [Discord](https://discord.com/users/319490489411829761).
