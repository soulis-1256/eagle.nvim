# hoverhints.nvim
The biggest step to bringing **IDE Grade mouse support** *(at least)* to our favorite Text Editor is finally here. I have prepared the first big update of my plugin, with many integrations and improvements compared to my initial implementation. I am happy to provide an outlook on all the features of this update.

### Complete integration with the Diagnostic API
It was a challenge to achieve this functionality, a lot of thinking went into the different ways I could make use of the native Diagnostic API.
https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/cfbc6e2d-fc20-4e96-9f6c-b7270fbe4695

### Different Diagnostics, Different Colors
This was the polishing touch, a way to make this stand out compared to IDEs.


### Move the Mouse, Change the Message
Neovim will update the floating diagnostic window, as soon as it detects a change in diagnostics under the current mouse position.


---
### Overview
- Neovim will now know if the mouse is over an underlined part of text, including nested underlines. High accurary, high precision, clean user experience.
- Neovim will know what kind of diagnostic is under the current mouse position, if there are multiple diagnostics on this position, and if all the different diagnostics have mixed severities. The style of the floating window will adapt accordingly.
- When the mouse moves, Neovim will be able to detect if the new position has a different diagnostic message, in cases where the same line can have different messages in different places.

### Notes
- The plugin has been tested in Neovim version 0.9.4.

### Installation
Using [Lazy](https://github.com/folke/lazy.nvim):
```
{
    "soulis-1256/hoverhints.nvim"
},
```

### Setup
All the configurable options are in the "defaults" table of [config.lua](./lua/hoverhints/config.lua).
```
require("hoverhints").setup({})
```

### Coming Up
- Integration with the LSP API, (contents of vim.lsp.buf.hover()). All the info, be it diagnostics, function or class declarations, variable definitions, will be contained inside the floating window of this plugin. This will be the next step of my development, so there is already a lot of work ahead.

---
### Support
You can support me through [PayPal](https://www.paypal.com/paypalme/soulis1256). Besides that, I'll be happy [to receive](https://discord.com/users/319490489411829761) your feedback and/or thoughts about this plugin.
