-- [[ init.lua ]]
-- v0.11+: Enable the byte-compiler for faster startup
if vim.loader then vim.loader.enable() end

-- Set <space> as the leader key (See :help mapleader)
--  NOTE: Must happen before plugins are required (so they can use it)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Load your core settings and keymaps
require('config.options')
require('config.keymaps')
require('config.autocmds')

-- [[ Install `lazy.nvim` plugin manager ]]
-- See :help lazy.nvim.txt or https://github.com/folke/lazy.nvim
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
end
vim.opt.rtp:prepend(lazypath)

-- Configure plugins from the /lua/plugins/ directory
require('lazy').setup({
  spec = {
    { import = 'plugins' },
    { import = 'themes' },
  },
})

-- AI provider toggle (<leader>ai) — loaded after plugins so both providers exist
require('config.ai-toggle')
