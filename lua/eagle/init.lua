local config = require("eagle.config")

local M = {}
M.setup = config.setup

local eagle_win = nil

--[[lock variable to prevent multiple windows from opening
this happens when the mouse moves faster than the time it takes
for a window to be created, especially during vim.lsp.buf_request_sync()
that contains vim.wait()]]
local win_lock = 0

local error_messages = {}
local lsp_info = {}

function M.create_eagle_win()
  local severity = ""
  local sameSeverity = true

  if #error_messages > 0 then
    severity = error_messages[1].severity

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
  else
    vim.api.nvim_set_hl(0, 'TitleColor', { fg = config.options.lsp_info_color })
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = config.options.lsp_info_color })
  end

  local max_width = math.ceil(vim.o.columns * config.options.max_width_factor)
  local messages = {}

  for i, error_message in ipairs(error_messages) do
    if #error_messages > 1 then
      table.insert(messages, i .. "." .. error_message.message)
    else
      table.insert(messages, error_message.message)
    end
  end


  if config.options.show_lsp_info then
    table.insert(messages, "───────── LSP Info ─────────")
    for _, md_line in ipairs(lsp_info) do
      table.insert(messages, md_line)
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

  local mouse_pos = vim.fn.getmousepos()
  local row_pos
  if mouse_pos.screenrow > math.floor(vim.o.lines / 2) then
    row_pos = mouse_pos.screenrow - num_lines - 3
  else
    row_pos = mouse_pos.screenrow
  end

  -- create a buffer with buflisted = false and scratch = true
  local buf = vim.api.nvim_create_buf(false, true)

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
  end

  -- Manually remove the first empty line if it exists
  local existingLines = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
  if #existingLines > 0 and existingLines[1] == "" then
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, {})
  end

  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  eagle_win = win
end

function M.load_lsp_info()
  lsp_info = {}
  local bufnr = vim.api.nvim_get_current_buf()

  local mouse_pos = vim.fn.getmousepos()
  local line = mouse_pos.line - 1
  local col = mouse_pos.column - 1

  local position_params = vim.lsp.util.make_position_params()

  position_params.position.line = line
  position_params.position.character = col

  local result

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

  if vim.tbl_isempty(lsp_info) then
    return
  end

  --local stylized_md = M.stylizeMarkdown(lsp_info)

  --return lsp_info
end

function M.stylizeMarkdown(inputString)
  local matchers = {
    block = { nil, '```+([a-zA-Z0-9_]*)', '```+' },
    pre = { nil, '<pre>([a-z0-9]*)', '</pre>' },
    code = { '', '<code>', '</code>' },
    text = { 'text', '<text>', '</text>' },
  }

  local match_begin = function(line)
    for type, pattern in pairs(matchers) do
      local ret = line:match(string.format('^%s*%s%s*$', '%%', pattern[2], '%%'))
      if ret then
        return {
          type = type,
          ft = pattern[1] or ret,
        }
      end
    end
  end

  local match_end = function(line, match)
    local pattern = matchers[match.type]
    return line:match(string.format('^%s*%s%s*$', '%%', pattern[3], '%%'))
  end

  -- Clean up
  local contents = inputString:gsub('\r\n', '\n')
  contents = contents:gsub('\r', '\n')
  contents = contents:gsub('\t', '  ')

  local stripped = {}
  local highlights = {}
  local markdown_lines = {}

  local lines = {}
  for line in contents:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local i = 1
  while i <= #lines do
    local line = lines[i]
    local match = match_begin(line)
    if match then
      local start = #stripped
      i = i + 1
      while i <= #lines do
        line = lines[i]
        if match_end(line, match) then
          i = i + 1
          break
        end
        table.insert(stripped, line)
        i = i + 1
      end
      -- Omitted: Logic to handle separators and markdown_lines
    else
      -- Omitted: Logic to handle empty lines and separators
      table.insert(stripped, line)
      i = i + 1
    end
  end

  return table.concat(stripped, '\n')
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
  callback = function(args)
    M.load_diagnostics()
  end,
})

function M.load_diagnostics()
  local has_diagnostics = false
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local mouse_pos = vim.fn.getmousepos()
  local diagnostics
  local prev_errors = error_messages
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
        has_diagnostics = true
        table.insert(error_messages, diagnostic)
      end
    end
  end

  if not vim.deep_equal(prev_errors, error_messages) then
    has_diagnostics = false
  end

  return has_diagnostics
end

local isMouseMoving = false

local renderDelayTimer = vim.loop.new_timer()

local function startRender()
  renderDelayTimer:stop()

  renderDelayTimer:start(config.options.render_delay, 0, vim.schedule_wrap(function()
    if #error_messages == 0 and #lsp_info == 0 then
      return
    end
    if win_lock == 0 then
      win_lock = 1
    else
      return
    end
    M.create_eagle_win()
  end))
end

function M.is_mouse_on_code()
  if eagle_win and vim.api.nvim_win_is_valid(eagle_win) and vim.api.nvim_get_current_win() == eagle_win then
    -- if we are on the eagle window, we should not skip any code
    return true
  end

  local mouse_pos = vim.fn.getmousepos()

  -- Get the line content at the specified line number (mouse_pos.line)
  local line_content = vim.fn.getline(mouse_pos.line)

  -- Check if the character under the mouse cursor is not:
  -- a) Whitespace
  -- b) After the last character of the current line
  -- c) Before the first character of the current line
  return ((mouse_pos.column ~= string.len(line_content) + 1) and (line_content:sub(mouse_pos.column, mouse_pos.column):match("%S") ~= nil) and mouse_pos.screencol >= vim.fn.wincol())
end

function M.process_mouse_pos()
  isMouseMoving = true

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

    startRender()
  end
end

function M.handle_eagle_focus()
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

  local isMouseWithinWestSide = (mouse_pos.screencol >= win_pad[2] + 1)
  local isMouseWithinEastSide = (mouse_pos.screencol <= (win_pad[2] + win_width + config.options.scrollbar_offset + 1))
  local isMouseWithinNorthSide = (mouse_pos.screenrow >= win_pad[1] + 1)
  local isMouseWithinSouthSide = (mouse_pos.screenrow <= (win_pad[1] + win_height + 2))

  -- if the mouse pointer is inside the eagle window, set it as the focused window
  if isMouseWithinWestSide and isMouseWithinEastSide and isMouseWithinNorthSide and isMouseWithinSouthSide then
    vim.api.nvim_set_current_win(eagle_win)
  else
    -- if the mouse pointer is outside the eagle window, close it
    vim.api.nvim_win_close(eagle_win, false)
    win_lock = 0
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

local last_line = -1

-- Function that detects if the user scrolled with the mouse wheel, based on vim.fn.getmousepos().line
local function detectScroll()
  local mousePos = vim.fn.getmousepos()

  if mousePos.line ~= last_line then
    last_line = mousePos.line
    M.process_mouse_pos()
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

vim.keymap.set('n', '<MouseMove>', M.process_mouse_pos, { silent = true })

--detect mode change, close eagle window when not in normal mode
vim.api.nvim_create_autocmd({ 'ModeChanged' }, {
  group = vim.api.nvim_create_augroup('ProcessMousePosOnModeChange', {}),
  callback = M.process_mouse_pos,
})

return M
