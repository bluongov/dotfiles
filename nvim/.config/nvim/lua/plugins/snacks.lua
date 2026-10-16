-- [[ lua/plugins/snacks.lua ]]
-- Website: https://github.com/folke/snacks.nvim
return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		picker = {
			enabled = true,
			follow = true, -- Follow symlinks globally (ripgrep skips them by default)
			formatters = {
				file = {
					filename_first = true, -- Displays filename first, then the dimmed directory path
				},
			},
		},
		dashboard = { enabled = true },
		notifier = {
			enabled = true,
			width = { min = 40, max = 80 },
		},
		terminal = { enabled = true },
	},
	keys = {
		{
			"<leader>nh",
			function()
				Snacks.notifier.show_history()
			end,
			desc = "Notification History",
		},
		{
			"<leader>lg",
			function()
				local root = Snacks.git.get_root()
				if not root then
					root = Snacks.git.get_root(vim.uv.cwd())
				end
				Snacks.lazygit({ cwd = root })
			end,
			desc = "Lazygit",
		},
		{
			"<leader>fb",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Buffers",
		},
		{
			"<leader>fh",
			function()
				Snacks.picker.help()
			end,
			desc = "Help Pages",
		},

		-- Snacks Picker
		{
			"<leader>fe",
			function()
				Snacks.picker.explorer()
			end,
			desc = "Fuzzy Explorer Tree",
		},
		{
			"<leader>fer",
			function()
				Snacks.picker.explorer({ layout = { layout = { position = "right" } } })
			end,
			desc = "Fuzzy Explorer Tree (Right)",
		},
		{
			"<leader>ff",
			function()
				Snacks.picker.files({ exclude = { "node_modules" } })
			end,
			desc = "Find Files",
		},
		{
			"<leader>fF",
			function()
				Snacks.picker.files({ ignored = true, hidden = true })
			end,
			desc = "Find Files (All)",
		},
		{
			"<leader>fg",
			function()
				Snacks.picker.grep({ exclude = { "node_modules" } })
			end,
			desc = "Grep Text",
		},
		{
			"<leader>fG",
			function()
				Snacks.picker.grep({ ignored = true, hidden = true })
			end,
			desc = "Grep Text (All)",
		},

		-- Git related
		{
			"<leader>gs",
			function()
				Snacks.picker.git_status()
			end,
			desc = "Git Status (Modified Files)",
		},
		{
			"<leader>gd",
			function()
				Snacks.picker.git_diff({ cmd_args = { vim.api.nvim_buf_get_name(0) } })
			end,
			desc = "Git Diff (Current File)",
		},
		{
			"<leader>gD",
			function()
				Snacks.picker.git_diff()
			end,
			desc = "Git Diff (Workspace)",
		},
		{
			"<leader>gf",
			function()
				Snacks.picker.git_log_file()
			end,
			desc = "Git Log (Current File)",
		},
		{
			"<leader>gl",
			function()
				Snacks.picker.git_log()
			end,
			desc = "Git Log (All Commits)",
		},
		{
			"<leader>gB",
			function()
				Snacks.gitbrowse()
			end,
			desc = "Git Browse",
		},

		-- Scratch
		{
			"<leader>.",
			function()
				Snacks.scratch()
			end,
			desc = "Toggle Scratch Buffer",
		},
		{
			"<leader>S",
			function()
				Snacks.scratch.select()
			end,
			desc = "Select Scratch Buffer",
		},

		-- key maps
		{
			"<leader>km",
			function()
				Snacks.picker.keymaps({ layout = "ivy" })
			end,
			desc = "Search Keymaps (Snacks Picker)",
		},

		-- smart find
		{
			"<leader><space>",
			function()
				Snacks.picker.smart()
			end,
			desc = "Smart Find Files",
		},
	},
}
