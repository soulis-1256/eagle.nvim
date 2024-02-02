# eagle.nvim
> [!IMPORTANT]\
> _There are some pretty big features coming (most notably displaying the contents of vim.lsp.buf.hover()). Some progress has been pushed into the "new_features" branch, you can check them out if you want to see what I've been preparing. The full development of this plugin has been temporarily on hold due to my ongoing University exams, scheduled to conclude around early March. Until then, I will only be handling important issues. Thank you in advance for your patience!_

> [!NOTE]\
> Resembling the abilities of an eagle, this Neovim plugin helps you "soar through" your editing environment. It implements a custom floating window that displays diagnostics (Errors, Warnings, Hints) provided by Neovim's Diagnostic API. The window opens and closes based on precise mouse movement detection.

### Overview
Enhance your Neovim experience by utilizing the following features:
- Detect when the mouse hovers over an underlined part of code, including nested code and diagnostics that are in different parts of the same line.
- Process what kind of diagnostic is under the current mouse position. If there are multiple diagnostics on the same position (ie error and warning), display them all in a numbered list.

### Complete integration with the Diagnostic API
It was a challenge to achieve this functionality, a lot of thinking went into the different ways I could utilize Neovim's Diagnostic API. The result is a robust diagnostic handling system, capable of managing any use case.
![api3](https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/3362d1ea-83a8-44b7-90f7-f5324fd2e713)

### Move the Mouse, Change the Message
Neovim will update the floating window as soon as it detects a change in diagnostics under the current mouse position.
![mssg3](https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/605dd43b-078a-46cd-971f-213c7a4c57be)

### Different Diagnostics, Different Colors
Compared to contemporary graphical environments, this design features a notably unique quality.
![colors3](https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/a24e91e3-05c6-4da9-92d8-bb7725bae1a9)

---

### Notes
- The plugin has been tested using Neovim versions {0.9.4, 0.9.5}.

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

### Coming Up
- Integration with the LSP API, (contents of vim.lsp.buf.hover()). All the info, be it diagnostics, function or class declarations, variable definitions, will be contained inside the floating window of this plugin. This will be the next step of my development, so there is already a lot of work ahead.

---
### Support
You can support me through [PayPal](https://www.paypal.com/paypalme/soulis1256). Besides that, I'll be happy [to receive](https://discord.com/users/319490489411829761) your feedback and/or thoughts about this plugin.