local M = {}

local defaults = {
  -- close the eagle window when you execute a command (pressing : on normal or visual mode)
  -- this is to avoid weird things happening when the eagle window is in focus
  -- set it to false if you want more control over the window
  close_on_cmd = true,

  --show lsp info (exact same contents as from vim.lsp.buf.hover()) in the eagle window
  show_lsp_info = true,

  --Offset that handles possible scrollbar plugins
  --by adding an offset column in the right side of the window.
  --If you don't know what I'm talking about, then
  --you don't need this option.
  scrollbar_offset = 0,

  --limit the height of the eagle window to vim.o.lines / max_height_factor
  --it should be any float number in the range [2.5, 5.0]
  --it doesnt take effect if you set it to anything outside that range
  max_height_factor = 2.5,

  --the delay between the mouse position arriving at a diagnostic
  --and the floating window opening
  render_delay = 500,

  --the timer before the mouse is considered idle
  --this is for detecting mouse wheel scroll
  detect_mouse_timer = 50,

  --offsets that can move the window in any direction
  --you can experiment with values and see what you like
  window_row = 0,
  window_col = 1,

  --window border options, from the api docs
  --"none": No border (default).
  --"single": A single line box.
  --"double": A double line box.
  --"rounded": Like "single", but with rounded corners ("╭" etc.).
  --"solid": Adds padding by a single whitespace cell.
  --"shadow": A drop shadow effect by blending with the background.
  border = "single",

  -- the title of the window
  title = "",

  --the position of the title
  --can be "left", "center" or "right"
  title_pos = "center",

  -- window title color
  title_color = "#8AAAE5",

  -- window border color
  border_color = "#8AAAE5",
}

M.options = {}

function M.setup(options)
  M.options = vim.tbl_deep_extend("force", defaults, options or {})
end

return M
