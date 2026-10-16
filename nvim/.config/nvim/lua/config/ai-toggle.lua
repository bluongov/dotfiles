-- [[ lua/config/ai-toggle.lua ]]
-- Toggles between GitHub Copilot Enterprise (work) and Supermaven (home).
-- Only one provider is active at a time to avoid double ghost text.
--
-- Usage:  <leader>ai  — opens a picker to switch providers
--
-- First-time Copilot setup:
--   1. Press <leader>ai and select "Copilot (Work)"
--   2. Run  :Copilot auth  and follow the device-code flow
--      (it will open https://etraid.ghe.com/login/device)

local M = {}

-- State: which provider is currently active ("supermaven" | "copilot")
vim.g.ai_provider = "supermaven"

--- Disable Supermaven completions
local function supermaven_disable()
  local ok, sm = pcall(require, "supermaven-nvim.completion_preview")
  if ok and sm then
    pcall(sm.clear_preview)
  end
  local ok2, api = pcall(require, "supermaven-nvim.api")
  if ok2 and api then
    pcall(api.deactivate)
  end
  vim.g.supermaven_active = false
end

--- Enable Supermaven completions
local function supermaven_enable()
  local ok, api = pcall(require, "supermaven-nvim.api")
  if ok and api then
    pcall(api.activate)
  end
  vim.g.supermaven_active = true
end

--- Disable Copilot completions
local function copilot_disable()
  local ok, suggestion = pcall(require, "copilot.suggestion")
  if ok and suggestion then
    if suggestion.is_visible() then suggestion.dismiss() end
    -- Turn off auto_trigger if it is on
    if vim.b.copilot_suggestion_auto_trigger then
      suggestion.toggle_auto_trigger()
    end
  end
  vim.g.copilot_active = false
end

--- Enable Copilot completions
local function copilot_enable()
  local ok, suggestion = pcall(require, "copilot.suggestion")
  if ok and suggestion then
    -- Turn on auto_trigger if it is off
    if not vim.b.copilot_suggestion_auto_trigger then
      suggestion.toggle_auto_trigger()
    end
  end
  vim.g.copilot_active = true
end

--- Switch to a provider by name ("supermaven" | "copilot")
function M.switch(provider)
  if provider == "copilot" then
    supermaven_disable()
    copilot_enable()
    vim.g.ai_provider = "copilot"
    vim.notify("AI: Copilot Enterprise (work)", vim.log.levels.INFO, { title = "AI Toggle" })
  elseif provider == "supermaven" then
    copilot_disable()
    supermaven_enable()
    vim.g.ai_provider = "supermaven"
    vim.notify("AI: Supermaven (home)", vim.log.levels.INFO, { title = "AI Toggle" })
  end
end

--- Open a simple picker to choose the active provider
function M.pick()
  local choices = {
    { label = "Supermaven  (home — free)",          value = "supermaven" },
    { label = "Copilot Enterprise  (work — etraid)", value = "copilot"    },
  }

  -- Build display items, marking the active one
  local items = vim.tbl_map(function(c)
    local active = vim.g.ai_provider == c.value and "  ✓ active" or ""
    return { text = c.label .. active, value = c.value }
  end, choices)

  -- Use vim.ui.select for a dependency-free picker
  vim.ui.select(items, {
    prompt = "Select AI provider:",
    format_item = function(item) return item.text end,
  }, function(choice)
    if choice then
      M.switch(choice.value)
    end
  end)
end

-- Register the keymap
vim.keymap.set("n", "<leader>ai", M.pick, { desc = "Toggle AI provider (Copilot/Supermaven)" })

-- ── Unified <Tab> handler ─────────────────────────────────────────────
-- Both Copilot and Supermaven have their own keymaps disabled.
-- This single <Tab> mapping checks whichever provider is active:
--   1. If the active AI has ghost text visible → accept it
--   2. If the LSP completion popup is open     → select next item
--   3. Otherwise                               → insert a normal tab
--
-- This prevents the two plugins from stomping on each other's keymaps.

--- Returns true if Supermaven has ghost-text extmarks in the current buffer.
local function supermaven_has_suggestion()
  for name, ns_id in pairs(vim.api.nvim_get_namespaces()) do
    if name:find("supermaven") then
      local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})
      if #marks > 0 then return true end
    end
  end
  return false
end

vim.keymap.set("i", "<Tab>", function()
  -- 1. Try the active AI provider
  if vim.g.copilot_active then
    local ok, suggestion = pcall(require, "copilot.suggestion")
    if ok and suggestion and suggestion.is_visible() then
      suggestion.accept()
      return
    end
  end

  if vim.g.supermaven_active then
    if supermaven_has_suggestion() then
      local ok, preview = pcall(require, "supermaven-nvim.completion_preview")
      if ok and preview then
        preview.on_accept_suggestion()
        return
      end
    end
  end

  -- 2. If the LSP completion popup is visible, select next item
  if vim.fn.pumvisible() == 1 then
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n", false)
    return
  end

  -- 3. Normal tab (insert real \t / spaces). Mode "n" = noremap, avoids recursion.
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
end, { desc = "Accept AI suggestion / complete / indent" })

return M
