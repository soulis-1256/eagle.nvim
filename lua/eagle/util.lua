local config = require('eagle.config')

local M = {}

-- keep track of eagle window id and eagle buffer id
local eagle_buf = nil

-- tables that hold the diagnostics and lsp info
--M.diagnostic_messages = {}
--M.lsp_info = {}

--load and sort all the diagnostics of the current buffer
--M.sorted_diagnostics = {}

function M.create_eagle_win()
    -- Determine position based on keyboard_mode setting
    local row_pos, col_pos
    if config.options.keyboard_mode then
        local cursor_pos = vim.fn.getcurpos()
        row_pos = cursor_pos[2] -- cursor line position
        col_pos = cursor_pos[3] -- cursor column position
    else
        local mouse_pos = vim.fn.getmousepos()
        row_pos = mouse_pos.screenrow
        col_pos = mouse_pos.screencol
    end

    local messages = {}

    if #M.diagnostic_messages > 0 then
        table.insert(messages, "# Diagnostics")
        table.insert(messages, "")
    end

    for i, diagnostic_message in ipairs(M.diagnostic_messages) do
        local message_parts = vim.split(diagnostic_message.message, "\n", { trimempty = false })
        for _, part in ipairs(message_parts) do
            if #M.diagnostic_messages > 1 then
                table.insert(messages, i .. ". " .. part)
            else
                table.insert(messages, part)
            end
        end

        local severity = diagnostic_message.severity

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
        table.insert(messages, "source: " .. diagnostic_message.source)

        -- some diagnostics may not fill the code field
        if diagnostic_message.code then
            table.insert(messages, "code: " .. diagnostic_message.code)
        end

        -- some diagnostics may not fill the hypertext reference field
        local href = diagnostic_message.user_data and
            diagnostic_message.user_data.lsp and diagnostic_message.user_data.lsp.codeDescription and
            diagnostic_message.user_data.lsp.codeDescription.href

        if href then
            table.insert(messages, "href: " .. diagnostic_message.user_data.lsp.codeDescription.href)
        end

        -- newline
        if i < #M.diagnostic_messages then
            table.insert(messages, "")
        end
    end

    if config.options.show_lsp_info and #M.lsp_info > 0 then
        if #M.diagnostic_messages > 0 then
            table.insert(messages, "---")
        end
        table.insert(messages, "# LSP Info")
        table.insert(messages, "")
        for _, md_line in ipairs(M.lsp_info) do
            table.insert(messages, md_line)
        end
    end

    -- create a buffer with buflisted = false and scratch = true
    if eagle_buf then
        vim.api.nvim_buf_delete(eagle_buf, {})
    end
    eagle_buf = vim.api.nvim_create_buf(false, true)

    -- this "stylizes" the markdown messages (diagnostics + lsp info)
    -- and attaches them to the eagle_buf
    vim.lsp.util.stylize_markdown(eagle_buf, messages, {})

    -- format long lines of the buffer
    M.format_lines(math.floor(vim.o.columns / config.options.max_width_factor))

    vim.api.nvim_set_option_value("modifiable", false, { buf = eagle_buf })
    vim.api.nvim_set_option_value("readonly", true, { buf = eagle_buf })

    -- Iterate over each line in the buffer to find the max width
    local lines = vim.api.nvim_buf_get_lines(eagle_buf, 0, -1, false)
    local max_line_width = 0
    for _, line in ipairs(lines) do
        local line_width = vim.fn.strdisplaywidth(line)
        max_line_width = math.max(max_line_width, line_width)
    end

    -- Calculate the window height based on the number of lines in the buffer
    local height = math.min(vim.api.nvim_buf_line_count(eagle_buf),
        math.floor(vim.o.lines / config.options.max_height_factor))

    -- need + 1 for hyperlinks (shift + click)
    local width = math.max(max_line_width + config.options.scrollbar_offset + 1,
        vim.fn.strdisplaywidth(config.options.title))

    if row_pos > math.floor(vim.o.lines / 2) then
        row_pos = row_pos - height - 3
    end

    vim.api.nvim_set_hl(0, 'TitleColor', { fg = config.options.title_color })
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = config.options.border_color })

    M.eagle_win = vim.api.nvim_open_win(eagle_buf, false, {
        title = { { config.options.title, "TitleColor" } },
        title_pos = config.options.title_pos,
        relative = 'editor',
        row = row_pos - config.options.window_row,
        col = col_pos - config.options.window_col,
        width = width,
        height = height,
        style = "minimal",
        border = config.options.border,
        focusable = true,
    })
end

-- format the lines of eagle_buf, in order to fit vim.o.columns / config.options.max_width_factor
-- for the case where an href link is splitted, I'm open to discussions on how to handle it
function M.format_lines(max_width)
    if not eagle_buf then
        -- Don't call format_lines if eagle_buf has not been created and filled with contents
        return
    end

    -- Iterate over the lines in the buffer
    local i = 0
    while i < vim.api.nvim_buf_line_count(eagle_buf) do
        -- Get the current line
        local line = vim.api.nvim_buf_get_lines(eagle_buf, i, i + 1, false)[1]

        -- If the line is too long
        if vim.fn.strdisplaywidth(line) > max_width then
            -- Check if the line is a markdown separator (contains only "─")
            if string.match(line, "^[─]+$") then
                -- If it's a markdown separator, truncate the line at max_width
                -- Notice we multiply max_width by 3, because this character takes up three bytes
                line = string.sub(line, 1, max_width * 3)
            else
                -- Find the last space character within the maximum line width
                local space_index = max_width
                while space_index > 0 and string.sub(line, space_index, space_index) ~= " " do
                    space_index = space_index - 1
                end

                -- If no space character was found within max_width, just split at max_width
                if space_index == 0 then
                    space_index = max_width
                end

                -- Split the line into two parts: the part that fits, and the remainder
                local part1 = string.sub(line, 1, space_index)
                local part2 = string.sub(line, space_index + 1)

                -- Replace the current line with the part that fits
                line = part1

                -- Insert the remainder as a new line after the current line
                vim.api.nvim_buf_set_lines(eagle_buf, i + 1, i + 1, false, { part2 })
            end
        end

        -- Replace the current line with the modified version
        vim.api.nvim_buf_set_lines(eagle_buf, i, i + 1, false, { line })

        -- Move to the next line
        i = i + 1
    end
end

function M.check_lsp_support()
    -- get the filetype of the current buffer
    local filetype = vim.bo.filetype

    -- get all active clients
    local clients = vim.lsp.get_clients()

    -- filter the clients based on the filetype of the current buffer
    local relevant_clients = {}
    for _, client in ipairs(clients) do
        if client.config.filetypes and vim.tbl_contains(client.config.filetypes, filetype) then
            table.insert(relevant_clients, client)
        end
    end

    -- check if any of the relevant clients support textDocument/hover
    for _, client in ipairs(relevant_clients) do
        if client.supports_method("textDocument/hover") then
            if config.options.debug_mode then
                print("Found LSP client supporting textDocument/hover: " .. client.name)
            end
            return true
        end
    end

    return false
end

function M.load_lsp_info(callback)
    --Ideally we need this binded with Event(s)
    --As of right now, WinEnter is a partial solution,
    --but it's not enough (for buffers etc).
    --BufEnter doesn't seem to work properly
    if not M.check_lsp_support() then
        return
    end

    M.lsp_info = {}

    local mouse_pos = vim.fn.getmousepos()
    local line = mouse_pos.line - 1
    local col = mouse_pos.column - 1

    local position_params = vim.lsp.util.make_position_params()

    position_params.position.line = line
    position_params.position.character = col

    local bufnr = vim.api.nvim_get_current_buf()

    -- asynchronous, so we need to use a callback function
    -- buf_request_sync contains vim.wait which is unwanted
    vim.lsp.buf_request_all(bufnr, "textDocument/hover", position_params, function(results)
        for _, result in pairs(results) do
            if result.result and result.result.contents then
                M.lsp_info = vim.lsp.util.convert_input_to_markdown_lines(result.result.contents)
            end
        end

        -- Call the callback function after lsp_info has been populated
        callback()
    end)
end

function M.sort_buf_diagnostics()
    M.sorted_diagnostics = vim.diagnostic.get(0, { bufnr = '%' })

    table.sort(M.sorted_diagnostics, function(a, b)
        return a.lnum < b.lnum
    end)
end

function M.load_diagnostics()
    local mouse_pos = vim.fn.getmousepos()
    local diagnostics
    local prev_diagnostics = M.diagnostic_messages
    M.diagnostic_messages = {}

    local pos_info = vim.inspect_pos(vim.api.nvim_get_current_buf(), mouse_pos.line - 1, mouse_pos.column - 1)
    for _, extmark in ipairs(pos_info.extmarks) do
        local extmark_str = vim.inspect(extmark)
        if string.find(extmark_str, "Diagnostic") then
            diagnostics = vim.diagnostic.get(0, { lnum = mouse_pos.line - 1 })

            --binary search on the sorted sorted_diagnostics table
            --needed for nested underlines (poor API)
            if #diagnostics == 0 then
                local outer_line
                if M.sorted_diagnostics then
                    local low, high = 1, #M.sorted_diagnostics
                    while low <= high do
                        local mid = math.floor((low + high) / 2)
                        local diagnostic = M.sorted_diagnostics[mid]
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
                table.insert(M.diagnostic_messages, diagnostic)
            end
        end
    end

    if not vim.deep_equal(M.diagnostic_messages, prev_diagnostics) then
        return false
    end

    return true
end

return M
