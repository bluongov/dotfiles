return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>f",
      function()
        require("conform").format({ async = true, lsp_fallback = true })
      end,
      mode = "",
      desc = "Format buffer",
    },
  },
  opts = {
    formatters = {
      prettier = {
        -- Use the prettier binary and config bundled with the etraid shared config.
        command = vim.fn.expand("~/.config/etraid_linter_formatter/node_modules/.bin/prettier"),
        prepend_args = {
          "--config",
          vim.fn.expand("~/.config/etraid_linter_formatter/.prettierrc.json"),
        },
      },
    },
    -- Define formatters for different filetypes
    formatters_by_ft = {
      javascript      = { "prettier" },
      typescript      = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      svelte          = { "prettier" },
      css             = { "prettier" },
      html            = { "prettier" },
      json            = { "prettier" },
      yaml            = { "prettier" },
      markdown        = { "prettier" },
      graphql         = { "prettier" },
      lua             = { "stylua" },
    },
    -- Format on save
    format_on_save = {
      timeout_ms = 500,
      lsp_fallback = true,
    },
  },
}
