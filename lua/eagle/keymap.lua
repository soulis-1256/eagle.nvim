--[[
-- With this module, the user can append a functionality to the list of preceding functions that were already binded to a key
-- Right now, Neovim uses special keys like <MouseMove>, <LeftMouse> etc to handle the mouse, instead of predefined events
-- Until the mouse events are implemented, this module does the work, making sure the user mappings can also be feeded
--]]

local function termcodes(keys)
  return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

local function keymap_equals(a, b)
  return termcodes(a) == termcodes(b)
end

local function get_preceding(mode, lhs)
  local function match_map(map)
    return keymap_equals(map.lhs, lhs) and map
  end

  local buf_maps = vim.api.nvim_buf_get_keymap(0, mode)
  local global_maps = vim.api.nvim_get_keymap(mode)
  local maps = vim.tbl_filter(match_map, vim.tbl_isempty(buf_maps) and global_maps or buf_maps)

  return vim.tbl_isempty(maps) and {
    lhs = lhs,
    rhs = lhs,
    expr = false,
    noremap = true,
    silent = true,
    buffer = false,
  } or vim.tbl_extend('force', maps[1], { buffer = not vim.tbl_isempty(buf_maps) })
end

local function feed_preceding(map)
  return function()
    local keys = map.expr and (map.callback and map.callback() or (map.rhs and vim.api.nvim_eval(map.rhs) or "")) or
        map.rhs
    vim.api.nvim_feedkeys(termcodes(keys), map.noremap and 'in' or 'im', false)
  end
end

local function append_keymap(mode, lhs, rhs, opts)
  mode = type(mode) == 'table' and mode or { mode }
  for _, m in ipairs(mode) do
    local map = get_preceding(m, lhs)
    opts = opts or {}
    opts.desc = string.format('[eagle.nvim:%s] %s', opts.desc and (': ' .. opts.desc) or '', map.desc or '')
    vim.keymap.set(m, lhs, function() rhs(feed_preceding(map)) end, opts)
  end
end

return append_keymap
