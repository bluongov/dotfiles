-- [[ lua/plugins/supermaven.lua ]]
-- Supermaven free-tier inline ghost text.
-- Starts ENABLED by default. Toggle with <leader>ai.
-- No account needed beyond a one-time signup at https://supermaven.com
return {
	"supermaven-inc/supermaven-nvim",
	event = "InsertEnter",
	config = function()
		require("supermaven-nvim").setup({
			-- Keymaps are handled by our unified <Tab> handler in ai-toggle.lua
			disable_keymaps = true,
			ignore_filetypes = {},
			color = {
				suggestion_color = "#6c7086", -- muted ghost text colour (works on dark themes)
				cterm = 244,
			},
			log_level = "off",
			disable_inline_completion = false,
		})

		vim.g.supermaven_active = true
	end,
}
