-- [[ lua/config/autocmds.lua ]]

-- Open an empty buffer when neo-tree is the only remaining window
vim.api.nvim_create_autocmd('BufEnter', {
  desc = 'Open empty buffer if neo-tree is the last window',
  callback = function()
    if #vim.api.nvim_list_wins() == 1 then
      local buf = vim.api.nvim_get_current_buf()
      if vim.bo[buf].filetype == 'neo-tree' then
        vim.cmd('wincmd p')
        if not vim.api.nvim_win_is_valid(0) then
          vim.cmd('leftabove new')
        end
      end
    end
  end,
})

-- Quit nvim entirely when :q is issued from neo-tree or a snacks picker
vim.api.nvim_create_autocmd("QuitPre", {
	desc = "Quit nvim when :q is run from neo-tree or a picker",
	callback = function()
		local ft = vim.bo[vim.api.nvim_get_current_buf()].filetype
		local special_fts = { ["neo-tree"] = true, ["snacks_picker_list"] = true, ["snacks_picker_input"] = true }
		if special_fts[ft] then
			vim.cmd("qall")
		end
	end,
})

-- Highlight when yanking (copying) text
-- See :help vim.hl.on_yank()
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking text",
	callback = function()
		vim.hl.on_yank()
	end,
})

-- Auto-open neo-tree as a sidebar when nvim is started with a directory argument
-- vim.api.nvim_create_autocmd('VimEnter', {
--   desc = 'Open neo-tree sidebar when opening a directory',
--   callback = function()
--     local arg = vim.fn.argv(0)
--     if arg and vim.fn.isdirectory(arg) == 1 then
--       require('neo-tree.command').execute({ action = 'show', dir = arg, position = 'right' })
--     end
--   end,
-- })

-- Per-window cwd: change the local cwd to the directory of the file you enter
vim.api.nvim_create_autocmd("BufEnter", {
	desc = "Set window-local cwd to directory of current file",
	callback = function()
		local bufname = vim.api.nvim_buf_get_name(0)
		-- Only act on real files (not terminals, pickers, etc.)
		if bufname ~= "" and vim.bo.buftype == "" then
			local dir = vim.fn.fnamemodify(bufname, ":h")
			if vim.fn.isdirectory(dir) == 1 then
				vim.cmd("lcd " .. vim.fn.fnameescape(dir))
			end
		end
	end,
})

-- Automatically enter Insert mode when jumping into a terminal buffer (like LazyGit)
vim.api.nvim_create_autocmd({ "BufEnter", "TermOpen" }, {
	group = vim.api.nvim_create_augroup("custom_term_open", { clear = true }),
	pattern = "term://*",
	callback = function()
		vim.cmd("startinsert")
	end,
})
