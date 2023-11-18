local config = require("hoverhints.config")

local M = {}
M.setup = config.setup

local error_win = nil
local original_win = vim.api.nvim_get_current_win()

-- variable that distincts this plugin's windows to any other window (like in telescope)
-- give it any value as long as there are no issues with other windows
local unique_lock = "1256"
local error_messages = {}

function M.create_float_window()
  local status, _ = pcall(vim.api.nvim_win_get_var, error_win, unique_lock)
  if status or not error_messages or #error_messages == 0 then
    return
  end

  local severity = error_messages[1].severity
  local sameSeverity = true

  for _, msg in ipairs(error_messages) do
    if msg.severity ~= severity then
      sameSeverity = false
      break
    end
  end

  if not sameSeverity then
    severity = "Mixed Severity Diagnostics"
    vim.api.nvim_set_hl(0, 'TitleColor', { fg = config.options.generic_color })
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = config.options.generic_color })
  else
    if severity == 1 then
      severity = "Error"
      vim.api.nvim_set_hl(0, 'TitleColor', { fg = config.options.error_color })
      vim.api.nvim_set_hl(0, 'FloatBorder', { fg = config.options.error_color })
    elseif severity == 2 then
      severity = "Warning"
      vim.api.nvim_set_hl(0, 'TitleColor', { fg = config.options.warning_color })
      vim.api.nvim_set_hl(0, 'FloatBorder', { fg = config.options.warning_color })
    elseif severity == 3 then
      severity = "Info"
      vim.api.nvim_set_hl(0, 'TitleColor', { fg = config.options.info_color })
      vim.api.nvim_set_hl(0, 'FloatBorder', { fg = config.options.info_color })
    elseif severity == 4 then
      severity = "Hint"
      vim.api.nvim_set_hl(0, 'TitleColor', { fg = config.options.hint_color })
      vim.api.nvim_set_hl(0, 'FloatBorder', { fg = config.options.hint_color })
    end
  end

  local mouse_pos = vim.fn.getmousepos()

  -- Handle the error by creating a custom window under the cursor
  local buf = vim.api.nvim_create_buf(false, true)
  local max_width = math.ceil(vim.o.columns * config.options.max_width_factor)
  local messages = {}

  for i, error_message in ipairs(error_messages) do
    if #error_messages > 1 then
      table.insert(messages, i .. "." .. error_message.message)
    else
      table.insert(messages, error_message.message)
    end
  end

  local num_lines = 0
  local max_line_width = 0

  for i, _ in ipairs(messages) do
    messages[i] = M.formatMessage(messages[i], max_width - config.options.scrollbar_offset)
    local lines = vim.split(messages[i], "\n")
    for _, line in ipairs(lines) do
      local line_width = vim.fn.strdisplaywidth(line)
      max_line_width = math.max(max_line_width, line_width)
      num_lines = num_lines + 1
    end
  end

  local width = math.min(max_line_width + config.options.scrollbar_offset, max_width)

  local row_pos
  if mouse_pos.screenrow > math.floor(vim.o.lines / 2) then
    row_pos = mouse_pos.screenrow - num_lines - 3
  else
    row_pos = mouse_pos.screenrow
  end

  local win = vim.api.nvim_open_win(buf, false, {
    title = { { severity, "TitleColor" } },
    title_pos = config.options.title_pos,
    relative = 'editor',
    row = row_pos - config.options.window_row,
    col = mouse_pos.screencol - config.options.window_col,
    width = width,
    height = num_lines,
    style = "minimal",
    border = config.options.border,
    focusable = true,
  })

  for _, message in ipairs(messages) do
    local lines = vim.fn.split(message, "\n")

    -- Set lines in the buffer for each message
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)

    -- Manually remove the first empty line if it exists
    local existingLines = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
    if #existingLines > 0 and existingLines[1] == "" then
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, {})
    end
  end

  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  --adding a custom value will identify the error window
  vim.api.nvim_win_set_var(win, unique_lock, "")
  error_win = win
end

function M.close_float_window(win)
  M.check_mouse_win_collision(win)

  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() ~= win then
    vim.api.nvim_win_close(win, false)
  end
end

--load all the diagnostics in a sorted table
local file_diagnostics

function M.load_diagnostics()
  file_diagnostics = vim.diagnostic.get(0, { bufnr = '%' })

  table.sort(file_diagnostics, function(a, b)
    return a.lnum < b.lnum
  end)
end

vim.api.nvim_create_autocmd('DiagnosticChanged', {
  callback = function(args)
    M.load_diagnostics()
  end,
})

function M.check_diagnostics()
  local has_diagnostics = false
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local mouse_pos = vim.fn.getmousepos()
  local diagnostics
  local prev_errors = error_messages
  error_messages = {}

  local pos_info = vim.inspect_pos(vim.api.nvim_get_current_buf(), mouse_pos.line - 1, mouse_pos.column - 1)
  for _, extmark in pairs(pos_info.extmarks) do
    local extmark_str = vim.inspect(extmark)
    if string.find(extmark_str, "Diagnostic") then
      diagnostics = vim.diagnostic.get(0, { lnum = mouse_pos.line - 1 })

      --binary search on the sorted file_diagnostics table
      --nested underlines (poor api)
      if #diagnostics == 0 then
        local outer_line
        if file_diagnostics then
          local low, high = 1, #file_diagnostics
          while low <= high do
            local mid = math.floor((low + high) / 2)
            local diagnostic = file_diagnostics[mid]
            if diagnostic.lnum < mouse_pos.line - 1 then
              outer_line = diagnostic.lnum
              low = mid + 1
            else
              high = mid - 1
            end
          end
        end
        diagnostics = vim.diagnostic.get(0, { lnum = outer_line })
      end
    end
  end

  if diagnostics and #diagnostics > 0 then
    for _, diagnostic in pairs(diagnostics) do
      local expr1, expr2, expr3

      expr1 = (diagnostic.lnum <= mouse_pos.line - 1) and (mouse_pos.line - 1 <= diagnostic.end_lnum)

      if expr1 then
        if diagnostic.lnum == diagnostic.end_lnum then
          expr2 = (diagnostic.col <= mouse_pos.column - 1) and (mouse_pos.column <= diagnostic.end_col)
          expr3 = true
        elseif diagnostic.lnum == mouse_pos.line - 1 then
          expr2 = diagnostic.col <= mouse_pos.column - 1
          expr3 = string.len(vim.fn.getline(mouse_pos.line)) ~= mouse_pos.column - 1
        else
          -- Get the line content at the specified line number (mouse_pos.line)
          local line_content = vim.fn.getline(mouse_pos.line)
          local non_whitespace_col

          -- Iterate through the characters in the line and find the index of the first non-whitespace character
          for i = 1, #line_content do
            local char = line_content:sub(i, i)
            if char:match("%S") then
              non_whitespace_col = i
              break
            end
          end

          -- Check if the character is not a whitespace character
          if ((string.len(line_content) ~= mouse_pos.column - 1) and mouse_pos.column >= non_whitespace_col) then
            expr2 = true
            expr3 = true
          end
        end
      end

      if expr1 and expr2 and expr3 then
        has_diagnostics = true
        table.insert(error_messages, diagnostic)
      end
    end
  end

  if not vim.deep_equal(prev_errors, error_messages) then
    return false
  end

  return has_diagnostics
end

local isMouseMoving = false

function show_diagnostics()
  isMouseMoving = true
  if vim.fn.mode() ~= 'n' then
    if error_win and vim.api.nvim_win_is_valid(error_win) and vim.fn.mode() ~= 'v' then
      M.close_float_window(error_win)
    end
    return
  end

  M.check_mouse_win_collision(vim.api.nvim_get_current_win())

  if M.check_diagnostics() then
    vim.defer_fn(function()
      M.create_float_window()
    end, config.options.render_delay)
  else
    if error_win and vim.api.nvim_win_is_valid(error_win) then
      M.close_float_window(error_win)
    end
  end
end

function M.check_mouse_win_collision(new_win)
  if (original_win == new_win) then
    return
  end

  local win_height = vim.api.nvim_win_get_height(new_win)
  local win_width = vim.api.nvim_win_get_width(new_win)
  local win_pad = vim.api.nvim_win_get_position(new_win)
  local mouse_pos = vim.fn.getmousepos()

  local expr1 = ((mouse_pos.screencol - 1) >= win_pad[2])
  local expr2 = ((mouse_pos.screencol - 1 - config.options.scrollbar_offset) <= (win_pad[2] + win_width))
  local expr3 = ((mouse_pos.screenrow - 1) >= win_pad[1])
  local expr4 = ((mouse_pos.screenrow - 2) <= (win_pad[1] + win_height))
  local expr5, _ = pcall(vim.api.nvim_win_get_var, new_win, unique_lock)

  if (expr1 and expr2 and expr3 and expr4) then
    vim.api.nvim_set_current_win(new_win)
  else
    if expr5 then
      vim.api.nvim_set_current_win(original_win)
    end
  end
end

local last_line = -1

-- Function that detects if the user scrolled with the mouse wheel, based on vim.fn.getmousepos().line
local function detectScroll()
  local mousePos = vim.fn.getmousepos()

  if mousePos.line ~= last_line then
    last_line = mousePos.line
    show_diagnostics()
  end
end

-- Detect if mouse is idle
vim.loop.new_timer():start(0, config.options.detect_mouse_timer or 50, vim.schedule_wrap(function()
  if isMouseMoving then
    isMouseMoving = false
  end
end))

-- Run detectScroll periodically
vim.loop.new_timer():start(0, 3 * (config.options.detect_mouse_timer or 50), vim.schedule_wrap(function()
  if (not isMouseMoving) then
    detectScroll()
  end
end))

vim.api.nvim_set_keymap('n', '<MouseMove>', '<cmd>lua show_diagnostics()<CR>', { noremap = true, silent = true })
vim.cmd([[
  augroup ShowDiagnosticsOnModeChange
    autocmd!
    autocmd ModeChanged * call v:lua.show_diagnostics()
  augroup END
]])

function M.formatMessage(message, maxWidth)
  local words = {}
  local currentWidth = 0
  local formattedMessage = ""

  for word in message:gmatch("%S+") do
    local wordWidth = vim.fn.strdisplaywidth(word)

    if currentWidth + wordWidth <= maxWidth then
      words[#words + 1] = word
      currentWidth = currentWidth + wordWidth + 1 --add 1 for the space between words
    else
      formattedMessage = formattedMessage .. table.concat(words, " ") .. "\n"
      words = { word }
      currentWidth = wordWidth + 1
    end
  end

  formattedMessage = formattedMessage .. table.concat(words, " ")

  return formattedMessage
end

return M
