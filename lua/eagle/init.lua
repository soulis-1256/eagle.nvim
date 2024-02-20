local config = require("eagle.config")

local M = {}
M.setup = config.setup

local eagle_win = nil
local eagle_buf = nil

--[[lock variable to prevent multiple windows from opening
this happens when the mouse moves faster than the time it takes
for a window to be created, especially during vim.lsp.buf_request_sync()
that contains vim.wait()]]
local win_lock = 0

--- call vim.fn.wincol() once in the beginning
local index_lock = 0
--- store the value of the starting column of actual code (skip line number columns etc)
local code_index

local error_messages = {}
local lsp_info = {}
local last_mouse_pos

function M.create_eagle_win()
  -- return if the mouse has moved exactly before the eagle window was to be created
  -- this can happen because of the render_delay
  local mouse_pos = vim.fn.getmousepos()
  if not vim.deep_equal(mouse_pos, last_mouse_pos) then
    win_lock = 0
    return
  end

  local messages = {}

  for i, error_message in ipairs(error_messages) do
    if #error_messages > 1 then
      table.insert(messages, i .. ". " .. error_message.message)
    else
      table.insert(messages, error_message.message)
    end

    local severity = error_message.severity

    if severity == 1 then
      severity = "Error"
    elseif severity == 2 then
      severity = "Warning"
    elseif severity == 3 then
      severity = "Info"
    elseif severity == 4 then
      severity = "Hint"
    end

    table.insert(messages, "severity: " .. severity)

    table.insert(messages, "code: " .. error_message.code)

    table.insert(messages, "source: " .. error_message.source)

    -- Not every diagnostic will provide a hypertext reference, unlike the code, source, severity and message fields
    local href = error_message.user_data and
        error_message.user_data.lsp and error_message.user_data.lsp.codeDescription and
        error_message.user_data.lsp.codeDescription.href

    if href then
      table.insert(messages, "href: " .. error_message.user_data.lsp.codeDescription.href)
    end

    -- newline
    table.insert(messages, "")
  end

  if config.options.show_lsp_info and #lsp_info > 0 then
    if #error_messages > 0 then
      table.insert(messages, "---")
    end
    table.insert(messages, "# LSP Info")
    table.insert(messages, "")
    for _, md_line in ipairs(lsp_info) do
      table.insert(messages, md_line)
    end
  end

  if config.options.max_height_factor < 2.5 or config.options.max_height_factor > 5.0 then
    config.options.max_height_factor = 2.5
  end

  -- create a buffer with buflisted = false and scratch = true
  if not eagle_buf then
    eagle_buf = vim.api.nvim_create_buf(false, true)
  end

  vim.bo[eagle_buf].modifiable = true
  vim.bo[eagle_buf].readonly = false

  vim.lsp.util.stylize_markdown(eagle_buf, messages, {})

  vim.bo[eagle_buf].modifiable = false
  vim.bo[eagle_buf].readonly = true

  -- Now calculate the number of lines in the buffer
  local num_lines = vim.api.nvim_buf_line_count(eagle_buf)

  -- Iterate over each line in the buffer to find the max width
  local lines = vim.api.nvim_buf_get_lines(eagle_buf, 0, -1, false)
  local max_line_width = 0
  for _, line in ipairs(lines) do
    local line_width = vim.fn.strdisplaywidth(line)
    max_line_width = math.max(max_line_width, line_width)
  end

  -- Calculate the window height based on the number of lines in the buffer
  local height = math.min(num_lines, math.floor(vim.o.lines / config.options.max_height_factor))
  local width = math.max(max_line_width + config.options.scrollbar_offset, vim.fn.strdisplaywidth(config.options.title))

  local row_pos
  if mouse_pos.screenrow > math.floor(vim.o.lines / 2) then
    row_pos = mouse_pos.screenrow - height - 3
  else
    row_pos = mouse_pos.screenrow
  end

  vim.api.nvim_set_hl(0, 'TitleColor', { fg = config.options.title_color })
  vim.api.nvim_set_hl(0, 'FloatBorder', { fg = config.options.border_color })

  eagle_win = vim.api.nvim_open_win(eagle_buf, false, {
    title = { { config.options.title, "TitleColor" } },
    title_pos = config.options.title_pos,
    relative = 'editor',
    row = row_pos - config.options.window_row,
    col = mouse_pos.screencol - config.options.window_col,
    width = width,
    height = height,
    style = "minimal",
    border = config.options.border,
    focusable = true,
  })
end

function M.load_lsp_info()
  lsp_info = {}

  --Ideally we need this binded with Event(s)
  --As of right now, WinEnter is a partial solution,
  --but it's not enough (for buffers etc).
  --BufEnter doesn't seem to work properly
  if not M.check_lsp_support() then
    return
  end

  local mouse_pos = vim.fn.getmousepos()
  local line = mouse_pos.line - 1
  local col = mouse_pos.column - 1

  local position_params = vim.lsp.util.make_position_params()

  position_params.position.line = line
  position_params.position.character = col

  local result
  local bufnr = vim.api.nvim_get_current_buf()

  result = vim.lsp.buf_request_sync(bufnr, "textDocument/hover", position_params)

  if not result or vim.tbl_isempty(result) then
    return
  end

  local response = result[1]
  if not (response and response.result and response.result.contents) then
    return
  end

  lsp_info = vim.lsp.util.convert_input_to_markdown_lines(response.result.contents)
  lsp_info = vim.lsp.util.trim_empty_lines(lsp_info)
end

--load and sort all the diagnostics of the current buffer
local buf_diagnostics

function M.sort_buf_diagnostics()
  buf_diagnostics = vim.diagnostic.get(0, { bufnr = '%' })

  table.sort(buf_diagnostics, function(a, b)
    return a.lnum < b.lnum
  end)
end

vim.api.nvim_create_autocmd('DiagnosticChanged', {
  callback = function()
    M.sort_buf_diagnostics()
  end,
})

function M.check_lsp_support()
  config.options.show_lsp_info = false

  -- check if the active clients support textDocument/hover
  local clients = vim.lsp.buf_get_clients()

  for _, client in ipairs(clients) do
    if client.supports_method("textDocument/hover") then
      config.options.show_lsp_info = true
      break
    end
  end

  return config.options.show_lsp_info
end

function M.load_diagnostics()
  local mouse_pos = vim.fn.getmousepos()
  local diagnostics
  error_messages = {}

  local pos_info = vim.inspect_pos(vim.api.nvim_get_current_buf(), mouse_pos.line - 1, mouse_pos.column - 1)
  for _, extmark in ipairs(pos_info.extmarks) do
    local extmark_str = vim.inspect(extmark)
    if string.find(extmark_str, "Diagnostic") then
      diagnostics = vim.diagnostic.get(0, { lnum = mouse_pos.line - 1 })

      --binary search on the sorted buf_diagnostics table
      --needed for nested underlines (poor API)
      if #diagnostics == 0 then
        local outer_line
        if buf_diagnostics then
          local low, high = 1, #buf_diagnostics
          while low <= high do
            local mid = math.floor((low + high) / 2)
            local diagnostic = buf_diagnostics[mid]
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
    for _, diagnostic in ipairs(diagnostics) do
      local isMouseWithinVerticalBounds, isMouseWithinHorizontalBounds

      -- check if the mouse is within the vertical bounds of the diagnostic (single-line or otherwise)
      isMouseWithinVerticalBounds = (diagnostic.lnum <= mouse_pos.line - 1) and
          (mouse_pos.line - 1 <= diagnostic.end_lnum)

      if isMouseWithinVerticalBounds then
        if diagnostic.lnum == diagnostic.end_lnum then
          -- if its a single-line diagnostic

          -- check if the mouse is within the horizontal bounds of the diagnostic
          isMouseWithinHorizontalBounds = (diagnostic.col <= mouse_pos.column - 1) and
              (mouse_pos.column <= diagnostic.end_col)
        else
          -- if its a multi-line diagnostic (nested)

          -- suppose we are always within the horizontal bounds of the diagnostic
          -- other checks (EOL, whitespace etc) were handled in process_mouse_pos (already optimized)
          isMouseWithinHorizontalBounds = true
        end
      end

      if isMouseWithinVerticalBounds and isMouseWithinHorizontalBounds then
        table.insert(error_messages, diagnostic)
      end
    end
  end
end

local isMouseMoving = false

local renderDelayTimer = vim.loop.new_timer()

local function startRender()
  renderDelayTimer:stop()

  last_mouse_pos = vim.fn.getmousepos()
  renderDelayTimer:start(config.options.render_delay, 0, vim.schedule_wrap(function()
    if win_lock == 0 then
      win_lock = 1
    else
      return
    end
    M.create_eagle_win()
  end))
end

function M.is_mouse_on_code()
  local mouse_pos = vim.fn.getmousepos()

  -- Get the line content at the specified line number (mouse_pos.line)
  local line_content = vim.fn.getline(mouse_pos.line)

  -- this is probably a "hacky" way, but it should work reliably
  if index_lock == 0 then
    code_index = vim.fn.wincol()
    index_lock = 1
  end

  -- Check if the character under the mouse cursor is not:
  -- a) Whitespace
  -- b) After the last character of the current line
  -- c) Before the first character of the current line
  return ((mouse_pos.column ~= vim.fn.strdisplaywidth(line_content) + 1) and (line_content:sub(mouse_pos.column, mouse_pos.column):match("%S") ~= nil) and mouse_pos.screencol >= code_index)
end

function M.process_mouse_pos()
  -- return if not in normal mode or if the mouse is not hovering over actual code
  if vim.fn.mode() ~= 'n' or not M.is_mouse_on_code() then
    renderDelayTimer:stop()
    if eagle_win and vim.api.nvim_win_is_valid(eagle_win) and vim.api.nvim_get_current_win() ~= eagle_win then
      M.handle_eagle_focus()
    end
    return
  end

  if eagle_win and vim.api.nvim_win_is_valid(eagle_win) then
    M.handle_eagle_focus()
  end

  if vim.api.nvim_get_current_win() ~= eagle_win then
    M.load_diagnostics()

    if config.options.show_lsp_info then
      M.load_lsp_info()
    end

    if #error_messages == 0 and #lsp_info == 0 then
      return
    end

    startRender()
  end
end

function M.handle_eagle_focus()
  -- if the eagle window is not open, return and make sure it can be re-rendered
  -- this is done with win_lock, to prevent the case where the user presses :q for the eagle window
  if not eagle_win or not vim.api.nvim_win_is_valid(eagle_win) then
    win_lock = 0
    return
  end

  local win_height = vim.api.nvim_win_get_height(eagle_win)
  local win_width = vim.api.nvim_win_get_width(eagle_win)
  local win_pad = vim.api.nvim_win_get_position(eagle_win)
  local mouse_pos = vim.fn.getmousepos()

  --[[
      referenced corner
      (0,0)
       ~###########################################
       #       ^                                  #
       #       |                                  #
       #   win_pad[1]                             #
       #       |       <- win_width ->            #
       #       v       ***************     ^      #
       #               *             *     |      #
       #               *             * win_height #
       #               *             *     |      #
       #               ***************     v      #
       #<- win_pad[2] ->                          #
       ############################################
  --]]

  -- west side shouldn't be completely accurate, we need an extra column for better user experience
  local isMouseWithinWestSide = (mouse_pos.screencol >= win_pad[2])

  local isMouseWithinEastSide = (mouse_pos.screencol <= (win_pad[2] + win_width + config.options.scrollbar_offset + 1))
  local isMouseWithinNorthSide = (mouse_pos.screenrow >= win_pad[1] + 1)
  local isMouseWithinSouthSide = (mouse_pos.screenrow <= (win_pad[1] + win_height + 2))

  -- if the mouse pointer is inside the eagle window and it's not already in focus, set it as the focused window
  if isMouseWithinWestSide and isMouseWithinEastSide and isMouseWithinNorthSide and isMouseWithinSouthSide then
    if vim.api.nvim_get_current_win() ~= eagle_win then
      vim.api.nvim_set_current_win(eagle_win)
      vim.api.nvim_win_set_cursor(eagle_win, { 1, 0 })
    end
  else
    -- close the window only if the mouse is not moving, or when the mouse is not over actual code
    if not isMouseMoving or not M.is_mouse_on_code() then
      vim.api.nvim_win_close(eagle_win, false)
      win_lock = 0
    end
  end
end

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

-- store the line of the last mouse position, in the case of scrolling
local last_line = -1

-- a lock variable that makes sure that process_mouse_pos() is only called once, when the mouse goes idle
local lock_processing = false

-- Function that detects if the user scrolled with the mouse wheel, based on vim.fn.getmousepos().line
local function detectScroll()
  local mousePos = vim.fn.getmousepos()

  if mousePos.line ~= last_line then
    last_line = mousePos.line
    M.handle_eagle_focus()
  end
end

-- detect if the mouse goes idle
vim.loop.new_timer():start(0, config.options.detect_mouse_timer or 50, vim.schedule_wrap(function()
  -- check if the view is scrolled, when the mouse is idle and the eagle window is not focused
  if not isMouseMoving and vim.api.nvim_get_current_win() ~= eagle_win then
    detectScroll()
  end

  if isMouseMoving then
    M.handle_eagle_focus()
    isMouseMoving = false
    lock_processing = false
  elseif not lock_processing then
    M.process_mouse_pos()
    lock_processing = true
  end
end))

vim.keymap.set('n', '<MouseMove>', function()
  isMouseMoving = true
end, { silent = true })

--detect mode change (close the eagle window when leaving normal mode)
vim.api.nvim_create_autocmd({ 'ModeChanged' }, {
  group = vim.api.nvim_create_augroup('ProcessMousePosOnModeChange', {}),
  callback = M.process_mouse_pos,
})

return M
