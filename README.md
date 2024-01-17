# hoverhints.nvim
⚠️ _There are some pretty big features coming. Some progress has been pushed into the "new_features" branch, you can check them out if you want to see what I've been preparing. The development for this plugin has been on hold due to my University exams. Regular commits will return when the exams are over, which should be around early March. Thank you in advance for your patience!_ ⚠️


This plugin implements a custom floating window that takes advantage of Neovim's Diagnostic API (Errors, Warnings, Hints). Here is an outlook on all the current features:

### Complete integration with the Diagnostic API
It was a challenge to achieve this functionality, a lot of thinking went into the different ways I could make use of the native Diagnostic API. The result is a great nested diagnostic handling system.
![api3](https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/3362d1ea-83a8-44b7-90f7-f5324fd2e713)

### Different Diagnostics, Different Colors
This was the polishing touch, a way to make this stand out compared to IDEs.
![colors3](https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/a24e91e3-05c6-4da9-92d8-bb7725bae1a9)

### Move the Mouse, Change the Message
Neovim will update the floating diagnostic window, as soon as it detects a change in diagnostics under the current mouse position.
![mssg3](https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/605dd43b-078a-46cd-971f-213c7a4c57be)

---
### Overview
- Neovim will now know if the mouse is over an underlined part of text, including nested underlines.
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
