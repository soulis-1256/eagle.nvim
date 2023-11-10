local error_win = nil
local scrollbar_offset = 1
local original_win = vim.api.nvim_get_current_win()
-- variable that distincs this plugin's windows to any other window (like in telescope)
-- name this whatever, with any value
local unique_lock = "1256"
local error_messages = {}
local border = "rounded"
local title_pos = "left"

function create_float_window()
  local status, _ = pcall(vim.api.nvim_win_get_var, error_win, unique_lock)
  if status then
    return
  end

  local mouse_pos = vim.fn.getmousepos()

  -- Handle the error by creating a custom window under the cursor
  local buf = vim.api.nvim_create_buf(false, true)
  local max_width_percentage = 0.3
  local max_width = math.floor(vim.o.columns * max_width_percentage)
  local counter = 0
  local messages = {}

  for _, error_message in pairs(error_messages) do
    local lines = vim.split(error_message.message, "\n")

    -- Concatenate the message with a numbered list format
    if #error_messages > 1 then
      counter = counter + 1
      table.insert(messages, counter .. "." .. table.concat(lines, "\n"))
    else
      table.insert(messages, table.concat(lines, "\n"))
    end
  end

  local severity
  local error_color = "#db4b4b"
  local warning_color = "#e0af68"
  local info_color = "#0db9d7"
  local hint_color = "#00ff00"

  if error_messages[1].severity == 1 then
    severity = "Error"
    vim.api.nvim_set_hl(0, 'TitleColor', { fg = error_color })
    vim.api.nvim_set_hl(0, "FloatBorder", { fg = error_color })
  elseif error_messages[1].severity == 2 then
    severity = "Warning"
    vim.api.nvim_set_hl(0, 'TitleColor', { fg = warning_color })
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = warning_color })
  elseif error_messages[1].severity == 3 then
    severity = "Info"
    vim.api.nvim_set_hl(0, 'TitleColor', { fg = info_color })
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = info_color })
  elseif error_messages[1].severity == 4 then
    severity = "Hint"
    vim.api.nvim_set_hl(0, 'TitleColor', { fg = hint_color })
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = hint_color })
  end

  -- Calculate the position and size of the float window based on the concatenated messages
  local num_lines = math.floor(vim.fn.strdisplaywidth(table.concat(messages, "\n")) / max_width + 1)
  local width = math.min(math.floor(vim.fn.strdisplaywidth(table.concat(messages, "\n")) + 2), max_width)

  local row_pos
  if mouse_pos.screenrow > math.floor(vim.o.lines / 2) then
    row_pos = mouse_pos.screenrow - num_lines - 3
  else
    row_pos = mouse_pos.screenrow
  end

  local win = vim.api.nvim_open_win(buf, false, {
    title = { { severity, "TitleColor" } },
    title_pos = title_pos,
    relative = 'editor',
    row = row_pos,
    col = mouse_pos.screencol - 1,
    width = width,
    height = num_lines,
    style = "minimal",
    border = border,
    focusable = true,
  })

  -- Set the lines in the buffer with the concatenated messages
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, messages)

  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  -- You may want to set a variable to identify this window as an error window
  vim.api.nvim_win_set_var(win, unique_lock, "")
  error_win = win
end

function close_float_window(win)
  check_mouse_win_collision(win)

  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() ~= win then
    vim.api.nvim_win_close(win, false)
    -- Clear the error_messages table
    error_messages = {}
  end
end

--load all the diagnostics in a sorted table
local file_diagnostics

function load_diagnostics()
  file_diagnostics = vim.diagnostic.get(0, { bufnr = '%' })

  table.sort(file_diagnostics, function(a, b)
    return a.lnum < b.lnum
  end)
end

vim.api.nvim_create_autocmd('DiagnosticChanged', {
  callback = function(args)
    load_diagnostics()
  end,
})

function check_diagnostics()
  local has_diagnostics = false
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local mouse_pos = vim.fn.getmousepos()
  local diagnostics

  local pos_info = vim.inspect_pos(vim.api.nvim_get_current_buf(), mouse_pos.line - 1, mouse_pos.column - 1)
  for _, extmark in pairs(pos_info.extmarks) do
    local extmark_str = vim.inspect(extmark)
    if string.find(extmark_str, "DiagnosticUnderline") then
      diagnostics = vim.diagnostic.get(0, { lnum = mouse_pos.line - 1 })

      if #diagnostics == 0 then
        local outer_line
        if file_diagnostics then
          for i = #file_diagnostics, 1, -1 do
            local diagnostic = file_diagnostics[i]
            if diagnostic.lnum < mouse_pos.line - 1 then
              outer_line = diagnostic.lnum
              break
            end
          end
        end
        diagnostics = vim.diagnostic.get(0, { lnum = outer_line })
      end
    end
  end

  if diagnostics and #diagnostics > 0 then
    for _, diagnostic in pairs(diagnostics) do
      local expr1, expr2, expr3, expr4

      expr1 = (diagnostic.lnum <= mouse_pos.line - 1) and (mouse_pos.line - 1 <= diagnostic.end_lnum)
      expr2 = (diagnostic.lnum <= cursor_pos[1] - 1) and (cursor_pos[1] - 1 <= diagnostic.end_lnum)

      if expr1 and expr2 then
        if diagnostic.lnum == diagnostic.end_lnum then
          expr3 = (diagnostic.col <= mouse_pos.column - 1) and (mouse_pos.column <= diagnostic.end_col)
          --expr4 = (diagnostic.col <= cursor_pos[2] - 1) and (cursor_pos[2] <= diagnostic.end_col)
          expr4 = true
        elseif diagnostic.lnum == mouse_pos.line - 1 then
          expr3 = diagnostic.col <= mouse_pos.column - 1
          expr4 = string.len(vim.fn.getline(mouse_pos.line)) ~= mouse_pos.column - 1
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
            expr3 = true
            expr4 = true
          end
        end
      end

      if expr1 and expr2 and expr3 and expr4 then
        has_diagnostics = true
        table.insert(error_messages, diagnostic)
      end
    end
  end

  return has_diagnostics
end

local isMouseMoving = false

function show_diagnostics()
  isMouseMoving = true
  if vim.fn.mode() ~= 'n' then
    return
  end

  check_mouse_win_collision(vim.api.nvim_get_current_win())

  if check_diagnostics() then
    create_float_window()
  else
    if error_win and vim.api.nvim_win_is_valid(error_win) then
      close_float_window(error_win)
    end
  end
end

function check_mouse_win_collision(new_win)
  if (original_win == new_win) then
    return
  end

  local win_height = vim.api.nvim_win_get_height(new_win)
  local win_width = vim.api.nvim_win_get_width(new_win)
  local win_pad = vim.api.nvim_win_get_position(new_win)
  local mouse_pos = vim.fn.getmousepos()

  local expr1 = ((mouse_pos.screencol - 1) >= win_pad[2])
  local expr2 = ((mouse_pos.screencol - 1 - scrollbar_offset) <= (win_pad[2] + win_width))
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

-- making detect_mouse_timer smaller will make scroll detect faster
local detect_mouse_timer = 50
local detect_scroll_timer = 3 * detect_mouse_timer
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
vim.loop.new_timer():start(0, detect_mouse_timer, vim.schedule_wrap(function()
  if isMouseMoving then
    isMouseMoving = false
  end
end))

-- Run detectScroll periodically
vim.loop.new_timer():start(0, detect_scroll_timer, vim.schedule_wrap(function()
  if (not isMouseMoving) then
    detectScroll()
  end
end))

vim.api.nvim_set_keymap('n', '<MouseMove>', '<cmd>lua show_diagnostics()<CR>', { noremap = true, silent = true })
