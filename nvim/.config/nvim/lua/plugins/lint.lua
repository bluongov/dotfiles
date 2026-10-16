return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")

		local etraid_dir = vim.fn.expand("~/.config/etraid_linter_formatter")
		local eslint_bin = etraid_dir .. "/node_modules/.bin/eslint"
		local config_path = etraid_dir .. "/eslint.config.mjs"

		-- Override the eslint_d linter to use the etraid local eslint binary directly.
		-- We redefine the linter completely so we aren't tied to eslint_d at all.
		lint.linters.eslint_d = {
			cmd = eslint_bin,
			args = {
				"--config",
				config_path,
				"--stdin",
				"--stdin-filename",
				function()
					return vim.api.nvim_buf_get_name(0)
				end,
			},
			stdin = true,
			stream = "stdout",
			ignore_exitcode = true,
			parser = require("lint.linters.eslint").parser,
			cwd = function()
				return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h")
			end,
		}

		lint.linters_by_ft = {
			javascript = { "eslint_d" },
			typescript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			svelte = { "eslint_d" },
		}

		-- Trigger linting on these events.
		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
		vim.api.nvim_create_autocmd({
			"BufEnter",
			"BufWritePost",
			"InsertLeave",
			"TextChanged",
		}, {
			group = lint_augroup,
			callback = function()
				-- Skip special buffers (terminals, neo-tree, floating windows, etc.)
				if vim.bo.buftype ~= "" then
					return
				end
				lint.try_lint()
			end,
		})

		vim.keymap.set("n", "<leader>l", function()
			lint.try_lint()
		end, { desc = "Trigger linting for current file" })
	end,
}
