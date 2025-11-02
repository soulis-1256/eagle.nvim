local config = require('eagle.config')
local util = require('eagle.util')

local M = {}

-- store the line of the last mouse position, needed to detect scrolling
local last_mouse_line = -1

-- Initialize last_pos as a global variable
local last_pos = nil

local renderDelayTimer = vim.uv.new_timer()

-- needed to block the creation of eagle_win when the mouse moves before the render delay timer is done
local last_mouse_pos = nil

--[[lock variable to prevent multiple windows from opening
this happens when the mouse moves faster than the time it takes
for a window to be created, especially during vim.lsp.buf_request_sync()
that contains vim.wait()]]
--M.win_lock = 0

local function render_mouse_mode()
    renderDelayTimer:stop()

    last_mouse_pos = vim.fn.getmousepos()
    
    if config.options.logging then
        print(string.format("[Eagle Mouse] render_mouse_mode: pos=(%d,%d), win_lock=%d", 
            last_mouse_pos.line, last_mouse_pos.column, M.win_lock))
    end
    
    renderDelayTimer:start(config.options.render_delay, 0, vim.schedule_wrap(function()
        if config.options.logging then
            print("[Eagle Mouse] Timer fired, checking diagnostics...")
        end
        
        -- if the window is open, we need to check if there are new diagnostics on the same line
        -- this is done with the highest priority, once the mouse goes idle
        if util.load_diagnostics(false) then
            if M.win_lock == 0 then
                M.win_lock = 1
            else
                if config.options.logging then
                    print("[Eagle Mouse] win_lock already set, returning")
                end
                return
            end
        else
            if util.eagle_win and vim.api.nvim_win_is_valid(util.eagle_win) then
                vim.api.nvim_win_close(util.eagle_win, false)
                M.win_lock = 0

                -- restart the timer with half of <config.options.render_delay>,
                -- invoking M.create_eagle_win() and returning immediately
                renderDelayTimer:stop()
                renderDelayTimer:start(math.floor(config.options.render_delay / 2), 0,
                    vim.schedule_wrap(function()
                        local mouse_pos = vim.fn.getmousepos()
                        if not vim.deep_equal(mouse_pos, last_mouse_pos) then
                            M.win_lock = 0
                        else
                            util.create_eagle_win(false)
                        end
                    end))
                return
            end
        end

        if config.options.show_lsp_info then
            -- Pass a function to M.load_lsp_info() that calls M.create_eagle_win()
            util.load_lsp_info(false, function()
                if #util.diagnostic_messages == 0 and #util.lsp_info == 0 then
                    return
                end
                local mouse_pos = vim.fn.getmousepos()
                if not vim.deep_equal(mouse_pos, last_mouse_pos) then
                    M.win_lock = 0
                else
                    util.create_eagle_win(false)
                end
            end)
        else
            -- If <config.options.show_lsp_info> is false, call M.create_eagle_win() directly
            if #util.diagnostic_messages == 0 then
                return
            end
            local mouse_pos = vim.fn.getmousepos()
            if not vim.deep_equal(mouse_pos, last_mouse_pos) then
                M.win_lock = 0
            else
                util.create_eagle_win(false)
            end
        end
    end))
end

function M.is_mouse_on_code()
    local mouse_pos = vim.fn.getmousepos()

    -- Guard against invalid positions
    if mouse_pos.winid == 0 or mouse_pos.line < 1 then
        if config.options.logging then
            print("[Eagle Mouse] is_mouse_on_code: no valid window under cursor")
        end
        return false
    end

    -- Get the line content at the specified line number (mouse_pos.line)
    local line_content = vim.fn.getline(mouse_pos.line)

    if config.options.logging then
        print(string.format("[Eagle Mouse] is_mouse_on_code: pos=(%d,%d), screencol=%d, column=%d, line_len=%d, line='%s'", 
            mouse_pos.line, mouse_pos.column, mouse_pos.screencol, mouse_pos.column, #line_content, line_content))
    end

    -- Check if mouse is on valid screen position
    if mouse_pos.column == 0 then
        if config.options.logging then
            print("[Eagle Mouse] is_mouse_on_code: before code area (line numbers/signs)")
        end
        return false
    end

    -- Check if line is empty
    if #line_content == 0 then
        if config.options.logging then
            print("[Eagle Mouse] is_mouse_on_code: empty line")
        end
        return false
    end

    -- Use the byte column reported by getmousepos()
    local byte_col = mouse_pos.column
    
    -- Check if we're past the end of the line
    if byte_col > #line_content then
        if config.options.logging then
            print(string.format("[Eagle Mouse] is_mouse_on_code: past end of line (byte_col=%d > line_len=%d)", byte_col, #line_content))
        end
        return false
    end

    -- Check if the character at this position is not whitespace
    local char_at_pos = line_content:sub(byte_col, byte_col)
    local is_on_code = char_at_pos:match("%S") ~= nil
    
    if config.options.logging then
        print(string.format("[Eagle Mouse] is_mouse_on_code: byte_col=%d, char='%s', result=%s", 
            byte_col, char_at_pos, tostring(is_on_code)))
    end
    
    if is_on_code then
        last_pos = vim.fn.getmousepos()
        return true
    end
    return false
end

function M.process_mouse_pos()
    if config.options.logging then
        print(string.format("[Eagle Mouse] process_mouse_pos: mode=%s", vim.fn.mode()))
    end
    
    -- return if not in normal mode or if the mouse is not hovering over actual code
    if vim.fn.mode() ~= 'n' or not M.is_mouse_on_code() then
        renderDelayTimer:stop()
        if util.eagle_win and vim.api.nvim_win_is_valid(util.eagle_win) and vim.api.nvim_get_current_win() ~= util.eagle_win then
            M.manage_windows()
        end
        return
    end

    if util.eagle_win and vim.api.nvim_win_is_valid(util.eagle_win) then
        M.manage_windows()
    end

    if vim.api.nvim_get_current_win() ~= util.eagle_win then
        render_mouse_mode()
    end
end

function M.manage_windows()
    -- if the eagle window is not open, return and make sure it can be re-rendered
    -- this is done with M.win_lock, to prevent the case where the user presses :q for the eagle window
    if not util.eagle_win or not vim.api.nvim_win_is_valid(util.eagle_win) then
        M.win_lock = 0
        return
    end

    local win_height = vim.api.nvim_win_get_height(util.eagle_win)
    local win_width = vim.api.nvim_win_get_width(util.eagle_win)
    local win_pad = vim.api.nvim_win_get_position(util.eagle_win)
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
    -- for this reason we include win_pad[2]
    local isMouseWithinWestSide = (mouse_pos.screencol >= win_pad[2])

    -- east will always have an extra column
    -- keep in mind that win_width already includes config.options.scrollbar_offset
    local isMouseWithinEastSide = (mouse_pos.screencol <= (win_pad[2] + win_width + 2))

    local isMouseWithinNorthSide = (mouse_pos.screenrow >= win_pad[1] + 1)
    local isMouseWithinSouthSide = (mouse_pos.screenrow <= (win_pad[1] + win_height + 2))

    -- if the mouse pointer is inside the eagle window and it's not already in focus, set it as the focused window
    if isMouseWithinWestSide and isMouseWithinEastSide and isMouseWithinNorthSide and isMouseWithinSouthSide then
        if vim.api.nvim_get_current_win() ~= util.eagle_win and vim.api.nvim_win_get_config(util.eagle_win).focusable then
            vim.api.nvim_set_current_win(util.eagle_win)
            vim.api.nvim_win_set_cursor(util.eagle_win, { 1, 0 })
        end
    else
        if util.eagle_win and vim.api.nvim_win_is_valid(util.eagle_win) and vim.fn.mode() == "n" then
            -- close the window if the mouse is over or comes from a special character
            if not M.check_char(mouse_pos) and vim.api.nvim_get_current_win() ~= util.eagle_win then -- and (last_mouse_line ~= mouse_pos.line) then
                return
            end
        end
        -- focusable if created by the keyboard mode
        if vim.api.nvim_win_get_config(util.eagle_win).focusable then
            vim.api.nvim_win_close(util.eagle_win, false)
            M.win_lock = 0
        end
    end
end

function M.check_char(mouse_pos)
    if last_pos and last_pos.line ~= mouse_pos.line then
        last_pos = mouse_pos
        return true
    end
    -- Get the content of the current line using Vim's getline function
    local mouse_line_content = vim.fn.getline(mouse_pos.line)
    local last_line_content = last_pos and vim.fn.getline(last_pos.line)

    -- Extract the characters under last_pos and mouse_pos
    local mouse_char = mouse_line_content:sub(mouse_pos.column, mouse_pos.column)
    local last_char = last_pos and last_line_content and last_line_content:sub(last_pos.column, last_pos.column)

    -- If the characters are the same, return false
    if mouse_char == last_char then
        last_pos = mouse_pos
        return false
    end

    local function is_special_char(pos)
        local specialCharacters = ":<>{}%[%]()|+-%=`~?.,"

        -- Get the content of the current line using Vim's getline function
        local line_content = vim.fn.getline(pos.line)

        -- Check if the column is within the bounds of the line
        if pos.column <= #line_content then
            local char = line_content:sub(pos.column, pos.column)

            -- Check if the character is a special character or whitespace
            if string.find(specialCharacters, char, 1, true) or char:match("%s") then
                return true
            end
        end

        return false
    end

    -- Check if the current or last position was a special character
    local isCurrentSpecial = is_special_char(mouse_pos)
    local isLastSpecial = last_pos and is_special_char(last_pos)

    -- Always update last_pos
    last_pos = mouse_pos

    -- Return true if either the current or last position was a special character
    return isCurrentSpecial or isLastSpecial
end

-- Function that detects if the user scrolled with the mouse wheel, based on vim.fn.getmousepos().line
function M.handle_scroll()
    local mousePos = vim.fn.getmousepos()

    if mousePos.line ~= last_mouse_line then
        last_mouse_line = mousePos.line
        M.manage_windows()
    end
end

return M
