# hoverhints.nvim
This plugin is my attempt to implement, in Neovim, the hover hints functionality provided by other Editors/IDEs like VSCode, Clion etc. When the mouse cursor is on the same line as the Neovim cursor and lsp provides a diagnostic for that line, then a custom float window will appear, which you can interact with, using the mouse. This is demonstrated in the following video (in the last portion of the video I'm scrolling the main view using the mouse wheel, in case you get confused).

[demo.webm](https://github.com/soulis-1256/hoverhints.nvim/assets/118274635/f6332450-119c-4fcc-a3f3-913f541a54ef)

## Installation
Lazy:
```
"soulis-1256/hoverhints.nvim"
```
## Setup
```
require("hoverhints")
```
## Notes
- I have not yet found a Neovim plugin that does what I'm trying to achieve here. This is just the first version of what I have in mind and, as you can see in my following TODO list, there is a lot of room for improvement.
- The plugin has been tested in Neovim v0.9.4. I can't guarantee full compatibility with older versions of the editor.

## TODO
- [ ] Integrate vim.lsp.buf.hover() in the diagnostics window (definitions, declarations etc)
- [ ] Try to disable plugins like scrollbars for the diagnostics window (deem scrollbarOffset obsolete)
- [ ] More integration with lsp, like hovering over the whole scope/underline of a diagnostic
- [ ] Add config and setup options (like a delay between when the diagnostic window can be reopened on rapid mouse movement)

## Support
If you appreciate my work and would like to see more from me in this space, please consider making a financial contribution through my PayPal.Me link. Your support means a lot. Thank you.

[<img width="250" src="https://github.com/andreostrovsky/donate-with-paypal/blob/master/dark.svg">](https://www.paypal.com/paypalme/soulis1256)

<sub>Many thanks to [andreostrovsky](https://github.com/andreostrovsky/donate-with-paypal) for the donation image.</sub>
