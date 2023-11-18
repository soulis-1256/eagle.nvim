# hoverhints.nvim
This plugin implements a custom floating window that takes advantage of Neovim's Diagnostic API (Errors, Warnings, Hints). Here is an outlook on all the current features:

### Complete integration with the Diagnostic API
It was a challenge to achieve this functionality, a lot of thinking went into the different ways I could make use of the native Diagnostic API.
![api2](https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/13b6b29a-e12f-4f9d-9fef-a5fa5478acd0)

### Different Diagnostics, Different Colors
This was the polishing touch, a way to make this stand out compared to IDEs.
![colors2](https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/75fb3acc-8a7f-4310-8e42-aa77b7136ed3)

### Move the Mouse, Change the Message
Neovim will update the floating diagnostic window, as soon as it detects a change in diagnostics under the current mouse position.
![mssg2](https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/cb65c717-d1af-495e-9ba0-bdf313da5d33)

---
### Overview
- Neovim will now know if the mouse is over an underlined part of text, including nested underlines. High accurary, high precision, clean user experience.
- Neovim will know what kind of diagnostic is under the current mouse position, if there are multiple diagnostics on this position, and if all the different diagnostics have mixed severities. The style of the floating window will adapt accordingly.
- When the mouse moves, Neovim will be able to detect if the new position has a different diagnostic message, in cases where the same line can have different messages in different places.

### Notes
- The plugin has been tested using Neovim version 0.9.4.

### Installation
Using [Lazy](https://github.com/folke/lazy.nvim):
```lua
{
    "soulis-1256/hoverhints.nvim"
},
```

### Setup
All the configurable options are in the "defaults" table of [config.lua](./lua/hoverhints/config.lua).
```lua
require("hoverhints").setup({})
```

### Coming Up
- Integration with the LSP API, (contents of vim.lsp.buf.hover()). All the info, be it diagnostics, function or class declarations, variable definitions, will be contained inside the floating window of this plugin. This will be the next step of my development, so there is already a lot of work ahead.

---
### Support
You can support me through [PayPal](https://www.paypal.com/paypalme/soulis1256). Besides that, I'll be happy [to receive](https://discord.com/users/319490489411829761) your feedback and/or thoughts about this plugin.
