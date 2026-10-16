-- [[ lua/plugins/copilot.lua ]]
-- GitHub Copilot Enterprise inline ghost text.
-- Starts DISABLED by default. Toggle with <leader>ai.
-- On first use, run :Copilot auth to authenticate against your GHE instance.
return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	config = function()
		require("copilot").setup({
			-- Point at the Etraid GitHub Enterprise instance
			copilot_node_command = "node",
			server_opts_overrides = {
				settings = {
					advanced = {
						authProvider = "github-enterprise",
					},
				},
			},
			copilot_model = "gpt-5-mini",
			suggestion = {
				enabled = true,
				auto_trigger = true, -- show ghost text as you type
				hide_during_completion = true,
				debounce = 75,
				-- All keymaps set to false — handled by our unified <Tab> in ai-toggle.lua
				keymap = {
					accept = false,
					accept_word = false,
					accept_line = false,
					next = "<M-]>",
					prev = "<M-[>",
					dismiss = "<C-]>",
				},
			},
			panel = { enabled = false }, -- ghost text only, no popup panel
			filetypes = {
				["*"] = true, -- enable for all filetypes by default
			},
		})

		-- Start disabled; ai-toggle.lua controls activation
		require("copilot.suggestion").toggle_auto_trigger()
		vim.g.copilot_active = false
	end,
}
