return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	lazy = false, -- Need this to be false so that it can immediately hijack `nvim .` on startup
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
		"MunifTanjim/nui.nvim",
	},
	keys = {
		{
			"<leader>e",
			function()
				require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd() })
			end,
			desc = "Explorer NeoTree (cwd)",
		},
		{
			"<leader>eh",
			function()
				require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd(), position = "left" })
			end,
			desc = "Explorer NeoTree Left",
		},
		{
			"<leader>el",
			function()
				require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd(), position = "right" })
			end,
			desc = "Explorer NeoTree Right",
		},
		{
			"\\",
			function()
				require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd() })
			end,
			desc = "Explorer NeoTree (cwd)",
		},
	},
	opts = {
		window = {
			position = "right",
			mappings = {
				["l"] = "open",
				["h"] = "close_node",
				["H"] = "toggle_hidden",
				["ff"] = "snacks_find_files",
				["fg"] = "snacks_grep",
			},
		},
		commands = {
			snacks_find_files = function(state)
				local node = state.tree:get_node()
				local path = node:get_id()
				if node.type ~= "directory" then
					path = node:get_parent_id()
				end
				require("snacks").picker.files({ cwd = path })
			end,
			snacks_grep = function(state)
				local node = state.tree:get_node()
				local path = node:get_id()
				if node.type ~= "directory" then
					path = node:get_parent_id()
				end
				require("snacks").picker.grep({ dirs = { path } })
			end,
		},
		filesystem = {
			-- hijack_netrw_behavior = "open_default", -- Opens neo-tree as a sidebar when opening a directory
			filtered_items = {
				visible = false, -- false means they are completely hidden
				hide_dotfiles = true, -- hides hidden/private files (files starting with a dot)
				hide_gitignored = true, -- hides files ignored by git (like node_modules)
				hide_by_name = {
					-- "node_modules",
					"private",
				},
				always_show = { -- remains visible even if other settings would hide it
					-- ".env",
				},
			},
			follow_current_file = {
				enabled = true, -- This will find and focus the file in the active buffer every time
			},
		},
	},
}
