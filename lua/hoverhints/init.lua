local error_win = nil
local scrollbar_offset = 1
local original_win = vim.api.nvim_get_current_win()
-- variable that distincs this plugin's windows to any other window (like in telescope)
-- name this whatever, with any value
local unique_lock = "1256"

-- Function to create a floating window at specific screen coordinates
function create_float_window()
  local status, _ = pcall(vim.api.nvim_win_get_var, error_win, unique_lock)
  if status then
    return
  end

  local _, win = vim.diagnostic.open_float(0, {
    border = "single",
    focusable = true,
    focus = false,
  })
  vim.api.nvim_win_set_width(win, vim.api.nvim_win_get_width(win) + scrollbar_offset)

  -- Setting a custom value will ensure uniqueness, but it shouldn't be needed
  vim.api.nvim_win_set_var(win, unique_lock, "")
  error_win = win
end

function close_float_window(win)
  check_mouse_win_collision(win)

  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() ~= win then
    vim.api.nvim_win_close(win, false)
  end
end

function check_diagnostics()
  local diagnostics = vim.diagnostic.get(0, { bufnr = '%' })

  local has_diagnostics = false
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local mouse_pos = vim.fn.getmousepos()

  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.lnum == (mouse_pos.line - 1) and diagnostic.lnum == (cursor_pos[1] - 1) then
      has_diagnostics = true
      break
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
  if (check_diagnostics()) then
    create_float_window()
  else
    if error_win and vim.api.nvim_win_is_valid(error_win) then
      close_float_window(error_win)
      error_win = nil
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
    vim.cmd("lua show_diagnostics()")
  end
end

-- Timer that resets mouse movement after some time (detect if mouse isn't moving)
vim.loop.new_timer():start(0, detect_mouse_timer, vim.schedule_wrap(function()
  if isMouseMoving then
    isMouseMoving = false
  end
end))

-- Run detectScroll()
vim.loop.new_timer():start(0, detect_scroll_timer, vim.schedule_wrap(function()
  if (not isMouseMoving) then
    detectScroll()
  end
end))

vim.api.nvim_set_keymap('n', '<MouseMove>', '<cmd>lua show_diagnostics()<CR>', { noremap = true, silent = true })