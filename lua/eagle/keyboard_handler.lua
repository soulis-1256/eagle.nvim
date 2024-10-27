local util = require('eagle.util')
local config = require('eagle.config')

local M = {}

-- Function for keyboard-driven rendering (no delays, no mouse checks)
function M.render_keyboard_mode()
    util.load_diagnostics()

    if config.options.show_lsp_info then
        util.load_lsp_info(function()
            if #util.diagnostic_messages == 0 and #util.lsp_info == 0 then
                return
            end
            util.create_eagle_win()
        end)
    else
        if #util.diagnostic_messages == 0 then
            return
        end
        util.create_eagle_win()
    end
end

return M
