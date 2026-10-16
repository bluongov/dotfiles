-- [[ lua/config/keymaps.lua ]]
local set = vim.keymap.set

-- Theme switcher (lua/config/theme.lua)
-- <leader>tt opens a picker to choose and permanently save a colorscheme.
-- Any :colorscheme command also persists automatically (no keymap needed).
local theme = require("config.theme")
set("n", "<leader>tt", function()
	theme.pick()
end, { desc = "[T]heme picker" })

-- Clear search highlights on pressing <Esc> in normal mode
set("n", "<Esc>", "<cmd>nohlsearch<CR>")

--
set("v", "<leader>yc", '"+y', { desc = "Yank to system clipboard" })

-- Move lines with Alt+j/k
set("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
set("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })

-- Move selected lines
set("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selected line up" })
set("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selected line down" })

-- Better window navigation (Ctrl + hjkl) handled by vim-tmux-navigator plugin

-- Diagnostic keymaps (v0.11 preferred syntax)
set("n", "[d", function()
	vim.diagnostic.jump({ count = -1 })
end, { desc = "Go to previous diagnostic" })
set("n", "]d", function()
	vim.diagnostic.jump({ count = 1 })
end, { desc = "Go to next diagnostic" })
set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show full diagnostic message" })

-- Toggle inline diagnostic messages (signs stay, text toggles)
set("n", "<leader>dt", function()
	local current = vim.diagnostic.config().virtual_text
	if current then
		vim.diagnostic.config({ virtual_text = false })
		vim.notify("Diagnostics: signs only", vim.log.levels.INFO)
	else
		vim.diagnostic.config({
			virtual_text = {
				format = function(diagnostic)
					local msg = diagnostic.message
					if #msg > 60 then
						msg = msg:sub(1, 57) .. "..."
					end
					return msg
				end,
			},
		})
		vim.notify("Diagnostics: full inline", vim.log.levels.INFO)
	end
end, { desc = "[D]iagnostics [T]oggle inline text" })
