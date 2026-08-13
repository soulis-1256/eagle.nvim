local util = require('eagle.util')
local config = require('eagle.config')

local M = {}

-- Function for keyboard-driven rendering (no delays, no mouse checks)
function M.render_keyboard_mode()
    if util.is_eagle_win_valid() then
        if vim.api.nvim_get_current_win() == util.eagle_win then
            util.close_eagle_win()
            return
        else
            vim.api.nvim_set_current_win(util.eagle_win)
            return
        end
    end
    util.load_diagnostics(true)

    if config.options.show_lsp_info then
        util.load_lsp_info(true, function()
            if #util.diagnostic_messages == 0 and #util.lsp_info == 0 then
                return
            end
            util.create_eagle_win(true)
        end)
    else
        if #util.diagnostic_messages == 0 then
            return
        end
        util.create_eagle_win(true)
    end
end

return M
