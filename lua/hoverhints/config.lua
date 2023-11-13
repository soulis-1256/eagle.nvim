local M = {}

local defaults = {
  scrollbar_offset = 1,
  border = "rounded",
  title_pos = "left",
  error_color = "#db4b4b",
  warning_color = "#e0af68",
  info_color = "#0db9d7",
  hint_color = "#00ff00",
  generic_color = "#808080",
}

M.options = {}

function M.setup(options)
  M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

--M.setup()

return M;
