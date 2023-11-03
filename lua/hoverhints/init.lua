local error_win = nil
local scrollbar_offset = 1
local original_win = vim.api.nvim_get_current_win()
-- variable that distincs this plugin's windows to any other window (like in telescope)
-- name this whatever, with any value
local unique_lock = "1256"
local error_message

-- Function to create a floating window at specific screen coordinates
function create_float_window()
  local status, _ = pcall(vim.api.nvim_win_get_var, error_win, unique_lock)
  if status then
    return
  end

  local mouse_pos = vim.fn.getmousepos()

  local win = nil
  --[[local _, win = vim.diagnostic.open_float(0, {
    border = "single",
    focusable = true,
    focus = false,
  })]]
  if win then
    vim.api.nvim_win_set_width(win, vim.api.nvim_win_get_width(win) + scrollbar_offset)

    -- Setting a custom value will ensure uniqueness, but it shouldn't be needed
    vim.api.nvim_win_set_var(win, unique_lock, "")
  else
    -- Handle the error by creating a custom window under the cursor
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local buf = vim.api.nvim_create_buf(false, true)
    local num_lines = math.floor(vim.fn.strdisplaywidth(error_message) / vim.o.columns + 1)
    local width = math.floor(vim.fn.strdisplaywidth(error_message) + 2)

    win = vim.api.nvim_open_win(buf, false, {
      title = "Diagnostics",
      title_pos = "center",
      relative = 'editor',
      row = mouse_pos.screenrow,
      col = mouse_pos.screencol - 2,
      --row = cursor_pos[1] + 1, -- Adjust the row as needed
      --col = cursor_pos[2],
      width = width,
      height = num_lines,
      style = "minimal",
      border = 'single',
      focusable = true,
    })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(error_message, "\n"))

    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true

    -- You may want to set a variable to identify this window as an error window
    vim.api.nvim_win_set_var(win, unique_lock, "")
  end
  error_win = win
end

function close_float_window(win)
  check_mouse_win_collision(win)

  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() ~= win then
    vim.api.nvim_win_close(win, false)
  end
end

function check_diagnostics()
  local has_diagnostics = false
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local mouse_pos = vim.fn.getmousepos()

  local diagnostics = vim.diagnostic.get(0, { lnum = cursor_pos[1] - 1 })

  if #diagnostics > 0 then
    local diagnostic = diagnostics[1]

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

        --[[print("string.len: " ..
          string.len(line_content) .. ", col: " .. mouse_pos.column .. ", white: " .. non_whitespace)]]
        -- Check if the character is not a whitespace character
        if ((string.len(line_content) ~= mouse_pos.column - 1) and mouse_pos.column >= non_whitespace_col) then
          expr3 = true
          expr4 = true
        end
      end
    end

    --[[print("expr1: " ..
        tostring(expr1) ..
        ", expr2: " .. tostring(expr2) .. ", expr3: " .. tostring(expr3) .. ", expr4: " .. tostring(expr4) .. "lnum: " ..
        diagnostic.lnum ..
        ", col: " ..
        diagnostic.col ..
        ", end_lnum: " .. diagnostic.end_lnum .. ", end_col: " .. diagnostic.end_col)]]

    if expr1 and expr2 and expr3 and expr4 then
      has_diagnostics = true
      error_message = diagnostic.message
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

  --print("win: " .. new_win)

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
