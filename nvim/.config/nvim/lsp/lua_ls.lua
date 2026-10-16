-- Per-server config for lua_ls (used by vim.lsp.enable() in Neovim 0.11)
-- See: https://luals.github.io/wiki/settings/
return {
  settings = {
    Lua = {
      completion = {
        -- Disable postfix completions: these are the ones that insert '', "", [], {}
        -- e.g. typing ' triggers a '' postfix snippet -- very annoying
        postfix = false,
        autoRequire = false,     -- Don't auto-insert require() calls
        workspaceWord = true,    -- Keep word-based completions from workspace
        callSnippet = 'Disable', -- Don't expand function call snippets
      },
      diagnostics = {
        globals = { 'vim' },
      },
      runtime = {
        version = 'LuaJIT', -- Neovim uses LuaJIT
      },
      workspace = {
        checkThirdParty = false, -- Suppress "Do you need to configure your work environment?" popup
        library = vim.api.nvim_get_runtime_file('', true),
      },
    },
  },
}
