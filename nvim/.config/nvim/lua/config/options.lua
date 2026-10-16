-- [[ lua/config/options.lua ]]
-- See :help vim.opt
local opt = vim.opt

opt.clipboard:append("unnamedplus")
opt.hlsearch = true

opt.number = true -- Show line numbers
opt.relativenumber = true -- Relative numbers help with vertical jumping
opt.mouse = "a" -- Enable mouse support
opt.showmode = false -- Don't show mode (e.g. -- INSERT --) because statusline does it
opt.breakindent = true -- Wrapped lines keep indentation
opt.undofile = true -- Save undo history across sessions
opt.ignorecase = true -- Case-insensitive searching...
opt.smartcase = true -- ...unless \C or capital in search
opt.signcolumn = "yes" -- Always show the sign column (prevents "flicker")
opt.updatetime = 250 -- Faster completion and diagnostic display
opt.timeoutlen = 600 -- Give more time to press the leader key combo (was 300)
opt.splitright = true -- Put new windows to the right
opt.splitbelow = true -- Put new windows below
opt.cursorline = true -- Highlight the current line
opt.scrolloff = 10 -- Keep 10 lines above/below cursor
opt.smoothscroll = true -- v0.11 feature: pixel-perfect scrolling
opt.tabstop = 2 -- Number of spaces a <Tab> counts for visually
opt.shiftwidth = 2 -- Number of spaces used for each indentation step (>> / <<)
opt.expandtab = true -- Insert spaces instead of a tab character
opt.completeopt = { "menu", "menuone", "noinsert", "noselect", "popup" }

-- Show diagnostics in a floating window on hover
vim.api.nvim_create_autocmd("CursorHold", {
	callback = function()
		vim.diagnostic.open_float(nil, {
			focusable = false,
			close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
			border = "rounded",
			source = "always", -- Shows if it's from 'lua_ls', 'pyright', etc.
			prefix = " ",
			scope = "cursor",
		})
	end,
})
--[[
-- Diagnostics (inline warnings/errors)
vim.diagnostic.config({
  virtual_text = {
    format = function(diagnostic)
      -- Truncate message to 60 chars to keep it readable inline
      local msg = diagnostic.message
      if #msg > 60 then
        msg = msg:sub(1, 57) .. '...'
      end
      return msg
    end,
  },
  signs = true,        -- Show sign in the sign column
  underline = true,    -- Underline the diagnostic code
  update_in_insert = false,
})
]]

-- 120-Character line limit marker
opt.colorcolumn = "120"
