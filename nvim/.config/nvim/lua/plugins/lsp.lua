-- [[ lua/plugins/lsp.lua ]]
-- Website: https://github.com/neovim/nvim-lspconfig
return {
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
		},
		config = function()
			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = { "lua_ls", "pyright", "ts_ls" },
			})
			require("mason-tool-installer").setup({
				ensure_installed = {
					"prettier", -- prettier formatter
					"eslint_d", -- blazingly fast eslint
					"stylua", -- lua formatter
					"typescript-language-server", -- JS/TS LSP
				},
			})

			-- v0.11 LSP Enablement loop
			vim.iter({ "lua_ls", "pyright", "ts_ls" }):each(function(server)
				vim.lsp.enable(server)
			end)

			-- Global LspAttach logic for keymaps
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					local opts = { buffer = args.buf }

					-- v0.11 Native Completion — autotrigger so suggestions appear as you type.
					-- Keep menu-only behavior so text is not inserted until you confirm it.
					if client and client:supports_method("textDocument/completion") then
						vim.lsp.completion.enable(true, client.id, args.buf, {
							autotrigger = true,
							convert = function(item)
								return { abbr = item.label, word = item.label, menu = item.kind_hlgroup }
							end,
						})
					end

					-- ── Navigation ────────────────────────────────────────────────────
					vim.keymap.set(
						"n",
						"gd",
						vim.lsp.buf.definition,
						vim.tbl_extend("force", opts, { desc = "Go to definition" })
					)
					vim.keymap.set(
						"n",
						"K",
						vim.lsp.buf.hover,
						vim.tbl_extend("force", opts, { desc = "Hover documentation" })
					)
					vim.keymap.set(
						"n",
						"gI",
						vim.lsp.buf.implementation,
						vim.tbl_extend("force", opts, { desc = "Go to implementation" })
					)
					vim.keymap.set(
						"n",
						"gy",
						vim.lsp.buf.type_definition,
						vim.tbl_extend("force", opts, { desc = "Go to type definition" })
					)

					-- ── References / symbols (via Snacks picker for a nice UI) ────────
					vim.keymap.set("n", "gr", function()
						Snacks.picker.lsp_references()
					end, vim.tbl_extend("force", opts, { desc = "Find references" }))
					vim.keymap.set("n", "<leader>ds", function()
						Snacks.picker.lsp_symbols()
					end, vim.tbl_extend("force", opts, { desc = "Document symbols" }))
					vim.keymap.set("n", "<leader>ws", function()
						Snacks.picker.lsp_workspace_symbols()
					end, vim.tbl_extend("force", opts, { desc = "Workspace symbols" }))

					-- ── Code actions & rename ─────────────────────────────────────────
					vim.keymap.set(
						"n",
						"<leader>ca",
						vim.lsp.buf.code_action,
						vim.tbl_extend("force", opts, { desc = "Code action" })
					)
					vim.keymap.set(
						"n",
						"<leader>rn",
						vim.lsp.buf.rename,
						vim.tbl_extend("force", opts, { desc = "Rename symbol" })
					)
				end,
			})
		end,
	},
}
