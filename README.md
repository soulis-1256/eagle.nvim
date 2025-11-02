# eagle.nvim

***To soar like an eagle is to rise above all obstacles.***

Following either your mouse or your cursor, this plugin provides a custom floating (popup) window that displays any diagnostic (Error, Warning, Hint) returned by the [Diagnostic API](https://neovim.io/doc/user/diagnostic.html), along with lsp information returned by the [LSP API](https://neovim.io/doc/user/lsp.html).
### Overview
Enhance your Neovim experience by utilizing the following features:
- Detect when the mouse hovers over an underlined part of code. Once it goes idle (for a [configurable](./lua/eagle/config.lua) amount of time), the window will be invoked. I tried to mirror the way conventional GUI Editors like VS Code work.
- Display the Diagnostics under the current mouse position. If there are multiple diagnostics on the same position (ie Error and Warning), display them all in a numbered list. For better user experience, the window is re-rendered only once the mouse encounters a "special" character (like "{}.?:" and more). This means that it stays open if it detects mouse movement and you are still hovering over the same variable/function/operator name.
- Show LSP information (the same contents as with vim.lsp.buf.hover()).
- **Recently added opt-in support for keyboard control, which can work together with mouse control.**

![showcase_eagle](https://github.com/soulis-1256/eagle.nvim/assets/118274635/ec28d139-0087-4e0d-a52b-c217231b846e)
As you can see, the plugin's window is displaying all the information related to each position.

### Installation
With [Lazy](https://github.com/folke/lazy.nvim):
```lua
{
    "soulis-1256/eagle.nvim",
    opts = {
      --override the default values found in config.lua
    }
},
```

Alternative setup (without Lazy's `opts` property), in case you encounter any issues:
```lua
{ "soulis-1256/eagle.nvim" },
```

```lua
require("eagle").setup({
--override the default values found in config.lua
})
```

Example setup for [LazyVim](https://www.lazyvim.org/) that is confirmed to work (under `lua/plugins/`):
```lua
return {
  {
    "soulis-1256/eagle.nvim",
    config = function()
      require("eagle").setup({
        keyboard_mode = true
      })
      vim.keymap.set('n', '<Tab>', ':EagleWin<CR>', { noremap = true, silent = true })
    end,
  },
}
```

You can find the description of all the options in [config.lua](./lua/eagle/config.lua). Here is a concise list:

```lua
  show_headers = true,
  order = 1,
  improved_markdown = true,
  mouse_mode = true,
  keyboard_mode = false,
  logging = false,
  close_on_cmd = true,
  show_lsp_info = true,
  scrollbar_offset = 0,
  max_width_factor = 2,
  max_height_factor = 2.5,
  render_delay = 500,
  detect_idle_timer = 50,
  window_row = 1,
  window_col = 5,
  border = "single",
  title = "",
  title_pos = "center",
  title_color = "#8AAAE5",
  border_color = "#8AAAE5",
```

> [!IMPORTANT]\
> By default, `keyboard_mode` is disabled and `mouse_mode` is enabled, but they can both be enabled at the same time.

If you keep `mouse_mode` enabled, make sure `vim.o.mousemoveevent` is also enabled:
```lua
vim.o.mousemoveevent = true
```
If you enable `keyboard_mode`, make sure you set a **custom keymap** to be able to use the plugin using the keyboard:
```lua
vim.keymap.set('n', '<Tab>', ':EagleWin<CR>', { noremap = true, silent = true })
```

> [!NOTE]\
> The plugin is confirmed to work on build version `0.10.2` (`api level 12`)

### Support
You can support me by donating through [PayPal](https://www.paypal.com/paypalme/soulis1256) and by providing your feedback. You can message me on [Discord](https://discord.com/users/319490489411829761).
