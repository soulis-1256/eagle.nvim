local config = require('eagle.config')

local M = {}

-- keep track of eagle window id and eagle buffer id
local eagle_buf = nil

-- tables that hold the diagnostics and lsp info
--M.diagnostic_messages = {}
--M.lsp_info = {}

--load and sort all the diagnostics of the current buffer
--M.sorted_diagnostics = {}

--keyboard_event is the same as with M.create_eagle_win(keyboard_event)
local function getpos(keyboard_event)
    if keyboard_event then
        local cursor_pos = vim.fn.getcurpos()
        return { row = cursor_pos[2] - 1, col = cursor_pos[3] - 1 }
    else
        local mouse_pos = vim.fn.getmousepos()
        return { row = mouse_pos.line - 1, col = mouse_pos.column - 1 }
    end
end

function M.sort_buf_diagnostics()
    M.sorted_diagnostics = vim.diagnostic.get(0, { bufnr = '%' })

    table.sort(M.sorted_diagnostics, function(a, b)
        return a.lnum < b.lnum
    end)
end

-- format the lines of eagle_buf, in order to fit vim.o.columns / config.options.max_width_factor
-- for the case where an href link is splitted, I'm open to discussions on how to handle it
local function format_lines(max_width)
    if not eagle_buf then
        -- Don't call format_lines if eagle_buf has not been initialized
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

function M.debug_lsp_clients(opts)
    opts = opts or {}
    local output_to_buffer = opts.buffer or false
    local detailed = opts.detailed or false

    local clients = vim.lsp.get_clients()
    local output = {}

    -- Helper function to handle both buffer and print output
    local function add(str)
        if output_to_buffer then
            table.insert(output, str)
        else
            print(str)
        end
    end

    if #clients == 0 then
        add("No LSP clients found")
        if output_to_buffer then
            return output
        else
            return
        end
    end

    add("\n---- LSP Client Debug Information ----")
    add("Total clients: " .. #clients)

    for i, client in ipairs(clients) do
        add("\n" .. string.rep("=", 50))
        add("Client " .. i .. ": " .. (client.name or "unnamed"))
        add(string.rep("=", 50))

        -- Basic information
        add("\n## Basic Information")
        add("• Name: " .. (client.name or "unnamed"))
        add("• ID: " .. client.id)
        add("• Status: " .. (client.is_stopped and client.is_stopped() and "Stopped" or "Running"))

        -- Root directory
        if client.config and client.config.root_dir then
            add("• Root directory: " .. tostring(client.config.root_dir))
        end

        -- Filetypes
        if client.config and client.config.filetypes then
            add("• Supported filetypes: " .. vim.inspect(client.config.filetypes))
        else
            add("• Supported filetypes: none specified")
        end

        -- Attached buffers
        local attached_buffers = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.lsp.buf_is_attached(buf, client.id) then
                local name = vim.api.nvim_buf_get_name(buf)
                name = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[No Name]"
                local ft = vim.bo[buf].filetype
                table.insert(attached_buffers, { id = buf, name = name, ft = ft })
            end
        end

        add("\n## Attached Buffers (" .. #attached_buffers .. ")")
        if #attached_buffers > 0 then
            for _, buf in ipairs(attached_buffers) do
                add(string.format("• Buffer %d: %s (%s)", buf.id, buf.name, buf.ft))
            end
        else
            add("• None")
        end

        -- List supported methods
        add("\n## Supported Methods")
        local common_methods = {
            "textDocument/hover",
            "textDocument/signatureHelp",
            "textDocument/definition",
            "textDocument/implementation",
            "textDocument/references",
            "textDocument/documentSymbol",
            "textDocument/codeAction",
            "textDocument/codeLens",
            "textDocument/formatting",
            "textDocument/rangeFormatting",
            "textDocument/rename",
            "textDocument/completion",
            "textDocument/declaration",
            "textDocument/typeDefinition",
            "textDocument/publishDiagnostics",
            "textDocument/semanticTokens/full",
            "workspace/symbol",
        }

        for _, method in ipairs(common_methods) do
            add("• " .. method .. ": " .. tostring(client.supports_method(method)))
        end

        -- Server capabilities (detailed info)
        if client.server_capabilities then
            add("\n## Capabilities Details")

            -- Completion
            if client.server_capabilities.completionProvider then
                add("• Completion Provider:")
                if client.server_capabilities.completionProvider.triggerCharacters then
                    add("  - Trigger Characters: " ..
                        vim.inspect(client.server_capabilities.completionProvider.triggerCharacters))
                end
                if client.server_capabilities.completionProvider.resolveProvider then
                    add("  - Resolve Provider: true")
                end
            end

            -- Hover
            if type(client.server_capabilities.hoverProvider) == "table" then
                add("• Hover Provider Details: " .. vim.inspect(client.server_capabilities.hoverProvider))
            end

            -- Signature Help
            if client.server_capabilities.signatureHelpProvider then
                add("• Signature Help Provider:")
                if client.server_capabilities.signatureHelpProvider.triggerCharacters then
                    add("  - Trigger Characters: " ..
                        vim.inspect(client.server_capabilities.signatureHelpProvider.triggerCharacters))
                end
            end

            -- Code Actions
            if type(client.server_capabilities.codeActionProvider) == "table" then
                add("• Code Action Provider:")
                if client.server_capabilities.codeActionProvider.codeActionKinds then
                    add("  - Action Kinds: " ..
                        vim.inspect(client.server_capabilities.codeActionProvider.codeActionKinds))
                end
            end

            -- Semantic Tokens
            if client.server_capabilities.semanticTokensProvider then
                add("• Semantic Tokens Provider:")
                if client.server_capabilities.semanticTokensProvider.legend then
                    add("  - Token Types: " .. #client.server_capabilities.semanticTokensProvider.legend.tokenTypes)
                    add("  - Token Modifiers: " ..
                        #client.server_capabilities.semanticTokensProvider.legend.tokenModifiers)
                end
                if detailed then
                    add("  - Token Types List: " ..
                        vim.inspect(client.server_capabilities.semanticTokensProvider.legend.tokenTypes))
                    add("  - Token Modifiers List: " ..
                        vim.inspect(client.server_capabilities.semanticTokensProvider.legend.tokenModifiers))
                end
            end

            -- Workspace
            if client.server_capabilities.workspace then
                add("\n• Workspace Capabilities:")

                -- Workspace folders
                if client.server_capabilities.workspace.workspaceFolders then
                    add("  - Workspace Folders: Supported")
                end

                -- File operations
                if client.server_capabilities.workspace.fileOperations then
                    add("  - File Operations: Supported")
                end
            end

            -- Document Sync details
            if client.server_capabilities.textDocumentSync then
                local sync_kind = type(client.server_capabilities.textDocumentSync) == "table"
                    and client.server_capabilities.textDocumentSync.change
                    or client.server_capabilities.textDocumentSync

                local sync_kind_text = {
                    [0] = "None",
                    [1] = "Full",
                    [2] = "Incremental"
                }

                add("• Text Document Sync: " .. (sync_kind_text[sync_kind] or "Unknown"))

                if type(client.server_capabilities.textDocumentSync) == "table" then
                    local sync = client.server_capabilities.textDocumentSync
                    if sync.willSave then add("  - Will Save: true") end
                    if sync.willSaveWaitUntil then add("  - Will Save Wait Until: true") end
                    if sync.save then add("  - Did Save: true") end
                end
            end
        end

        -- Custom handlers
        local handlers = {}
        if client.handlers and detailed then
            add("\n## Custom Handlers")
            for handler_name, _ in pairs(client.handlers) do
                table.insert(handlers, handler_name)
            end
            table.sort(handlers)
            for _, handler_name in ipairs(handlers) do
                add("• " .. handler_name)
            end
        end

        -- Server settings
        if client.config and client.config.settings and detailed then
            add("\n## Server Settings")
            add(vim.inspect(client.config.settings))
        end

        -- Initialization options
        if client.config and client.config.init_options and detailed then
            add("\n## Initialization Options")
            add(vim.inspect(client.config.init_options))
        end
    end

    add("\n" .. string.rep("=", 50))

    -- Output to buffer if requested
    if output_to_buffer then
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
        vim.bo[buf].filetype = 'markdown'
        vim.bo[buf].modifiable = false
        vim.bo[buf].bufhidden = 'wipe'

        -- Open buffer in split window
        vim.cmd('split LSP-Debug')
        vim.api.nvim_win_set_buf(0, buf)
        return buf
    end
end

local function check_lsp_support()
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
            if config.options.logging then
                print("Found LSP client supporting textDocument/hover: " .. client.name)
            end
            return true
        end
    end

    return false
end

--keyboard_event is the same as with M.create_eagle_win(keyboard_event)
function M.load_lsp_info(keyboard_event, callback)
    --Ideally we need this binded with Event(s)
    --As of right now, WinEnter is a partial solution,
    --but it's not enough (for buffers etc).
    --BufEnter doesn't seem to work properly
    local has_lsp = check_lsp_support()

    if not has_lsp then
        if config.options.logging then
            print("No LSP support detected, skipping LSP info loading")
        end
        M.lsp_info = {}
        callback()
        return
    end

    M.lsp_info = {}

    local pos = getpos(keyboard_event)
    local clients = vim.lsp.get_clients()
    local win = vim.api.nvim_get_current_win()
    local position_params = vim.lsp.util.make_position_params(win, clients[1].offset_encoding or 'utf-16')

    position_params.position.line = pos.row
    position_params.position.character = pos.col

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

--keyboard_event is the same as with M.create_eagle_win(keyboard_event)
function M.load_diagnostics(keyboard_event)
    local pos = getpos(keyboard_event)
    local diagnostics
    local prev_diagnostics = M.diagnostic_messages
    M.diagnostic_messages = {}

    local pos_info = vim.inspect_pos(vim.api.nvim_get_current_buf(), pos.row, pos.col)
    for _, extmark in ipairs(pos_info.extmarks) do
        local extmark_str = vim.inspect(extmark)
        if string.find(extmark_str, "Diagnostic") then
            diagnostics = vim.diagnostic.get(0, { lnum = pos.row })

            --binary search on the sorted sorted_diagnostics table
            --needed for nested underlines (poor API)
            if #diagnostics == 0 then
                local outer_line
                if M.sorted_diagnostics then
                    local low, high = 1, #M.sorted_diagnostics
                    while low <= high do
                        local mid = math.floor((low + high) / 2)
                        local diagnostic = M.sorted_diagnostics[mid]
                        if diagnostic.lnum < pos.row then
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
            local cursor_in_v_bounds, cursor_in_h_bounds

            -- check if the mouse is within the vertical bounds of the diagnostic (single-line or otherwise)
            cursor_in_v_bounds = (diagnostic.lnum <= pos.row) and
                (pos.row <= diagnostic.end_lnum)

            if cursor_in_v_bounds then
                if diagnostic.lnum == diagnostic.end_lnum then
                    -- if its a single-line diagnostic

                    -- check if the mouse is within the horizontal bounds of the diagnostic
                    cursor_in_h_bounds = (diagnostic.col <= pos.col) and
                        (pos.col < diagnostic.end_col)
                else
                    -- if its a multi-line diagnostic (nested)

                    -- suppose we are always within the horizontal bounds of the diagnostic
                    -- other checks (EOL, whitespace etc) were handled in process_mouse_pos (already optimized)
                    cursor_in_h_bounds = true
                end
            end

            if cursor_in_v_bounds and cursor_in_h_bounds then
                table.insert(M.diagnostic_messages, diagnostic)
            end
        end
    end

    if not vim.deep_equal(M.diagnostic_messages, prev_diagnostics) then
        return false
    end

    return true
end

local function stylize_markdown_buffer(bufnr, contents, opts)
    opts = opts or {}
    contents = vim.split(table.concat(contents, '\n'), '\n', { trimempty = true })

    -- Set default width if not provided
    local width = opts.width or vim.api.nvim_win_get_width(0)
    local normalized = {}
    local in_code_block = false

    for _, line in ipairs(contents) do
        if line:match("^```") then
            -- Toggle code block status
            in_code_block = not in_code_block
            -- Add the line to track where code blocks start and end
            table.insert(normalized, line)
        elseif line == "---" then
            -- Render a full-width horizontal line for `---`
            table.insert(normalized, string.rep("─", width))
        else
            if in_code_block then
                --skip wrapping within code blocks
                table.insert(normalized, line)
            else
                -- Wrap non-code lines at the specified width
                local wrapped = vim.fn.split(line, [[\%]] .. width .. [[v]])
                vim.list_extend(normalized, wrapped)
            end
        end
    end

    -- Set up the buffer for markdown syntax
    vim.bo[bufnr].filetype = 'markdown'
    vim.treesitter.start(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, normalized)

    vim.wo[0].conceallevel = config.options.conceallevel
    vim.wo[0].concealcursor = config.options.concealcursor
end


--keyboard_event is true when the eagle window was invoked using the keyboard and not the mouse
--useful for hybrid scenario (keyboard + mouse enabled at the same time)
function M.create_eagle_win(keyboard_event)
    local messages = {}
    local has_diagnostics = #M.diagnostic_messages > 0
    local has_lsp_info = config.options.show_lsp_info and #M.lsp_info > 0

    local function add_diagnostics()
        if has_diagnostics then
            if config.options.show_headers then
                table.insert(messages, "# Diagnostics")
                table.insert(messages, "")
            end
        else
            return
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
    end

    local function add_lsp_info()
        if has_lsp_info then
            if config.options.show_headers then
                table.insert(messages, "# LSP Info")
                table.insert(messages, "")
            end
            for _, md_line in ipairs(M.lsp_info) do
                table.insert(messages, md_line)
            end
        end
    end

    -- Set row position based on mouse/cursor
    local row
    local relative
    local focusable
    if keyboard_event then
        row = vim.fn.winline()
        relative = 'cursor'
        focusable = false
    else
        row = vim.fn.getmousepos().screenrow
        relative = 'mouse'
        focusable = true
    end

    -- Determine if the window should be rendered above or below the mouse/cursor
    local render_above
    if row > math.floor(vim.o.lines / 2) then
        render_above = true
    else
        render_above = false
    end

    -- Adjust the order and insert '---' appropriately
    if config.options.order == 1 then
        add_diagnostics()
        if has_diagnostics and has_lsp_info then
            table.insert(messages, "---")
        end
        add_lsp_info()
    elseif config.options.order == 2 then
        if render_above then
            add_diagnostics()
            if has_diagnostics and has_lsp_info then
                table.insert(messages, "---")
            end
            add_lsp_info()
        else
            add_lsp_info()
            if has_diagnostics and has_lsp_info then
                table.insert(messages, "---")
            end
            add_diagnostics()
        end
    elseif config.options.order == 3 then
        add_lsp_info()
        if has_diagnostics and has_lsp_info then
            table.insert(messages, "---")
        end
        add_diagnostics()
    elseif config.options.order == 4 then
        if render_above then
            add_lsp_info()
            if has_diagnostics and has_lsp_info then
                table.insert(messages, "---")
            end
            add_diagnostics()
        else
            add_diagnostics()
            if has_diagnostics and has_lsp_info then
                table.insert(messages, "---")
            end
            add_lsp_info()
        end
    end

    -- create a buffer with buflisted = false and scratch = true
    if eagle_buf then
        vim.api.nvim_buf_delete(eagle_buf, {})
    end
    eagle_buf = vim.api.nvim_create_buf(false, true)

    -- this "stylizes" the markdown messages (diagnostics + lsp info)
    -- and attaches them to the eagle_buf
    if config.options.improved_markdown then
        stylize_markdown_buffer(eagle_buf, messages, {})
    else
        --old way, not recommended
        vim.lsp.util.stylize_markdown(eagle_buf, messages, {})
    end

    -- format long lines of the buffer
    format_lines(math.floor(vim.o.columns / config.options.max_width_factor))

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

    vim.api.nvim_set_hl(0, 'TitleColor', { fg = config.options.title_color })
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = config.options.border_color })

    --this determines if the window should be rendered above or below the mouse/cursor
    if render_above then
        row = config.options.window_row - height - 3
    else
        row = config.options.window_row
    end

    M.eagle_win = vim.api.nvim_open_win(eagle_buf, false, {
        title = { { config.options.title, "TitleColor" } },
        title_pos = config.options.title_pos,
        relative = relative,
        row = row,
        col = -config.options.window_col,
        width = width,
        height = height,
        style = "minimal",
        border = config.options.border,
        focusable = focusable,
    })
end

return M
