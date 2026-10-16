-- [[ lua/plugins/treesitter.lua ]]
-- Website: https://github.com/nvim-treesitter/nvim-treesitter
-- nvim-treesitter v1.x + Neovim v0.11+:
--   Highlight and indent are now built into Neovim.
--   The plugin only manages parser installation.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")

      -- Install parsers (the new v1.x API)
      ts.install({
        "lua", "python",
        "javascript", "typescript", "tsx",
        "css", "html", "json",
        "vimdoc", "vim",
        "markdown", "markdown_inline",
      })

      -- Enable treesitter-based highlighting and indentation (native v0.11+)
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          -- Attempt to start treesitter highlighting for this buffer
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },
}
