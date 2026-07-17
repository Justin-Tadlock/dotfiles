-- codecompanion.nvim requires plenary.nvim (async utilities) and
-- nvim-treesitter at runtime — both are declared here explicitly so this
-- file's dependencies are self-contained, even though nvim-treesitter is
-- also pulled in by plugins/treesitter.lua for parser installation.
--
-- Pinned to ^19.0.0 per the plugin's own installation docs, which warn that
-- the config schema has changed across versions (this file uses the
-- current `interactions` table, not the older `strategies` table you may
-- see in outdated blog posts/tutorials).
--
-- Needs ANTHROPIC_API_KEY set in the environment for the anthropic adapter.
-- Check https://codecompanion.olimorris.dev for anything beyond what's
-- configured here — this plugin's setup table changes fairly often.

vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  { src = "https://github.com/olimorris/codecompanion.nvim", version = vim.version.range("^19.0.0") },
})

local function load_codecompanion()
  require("codecompanion").setup({
    interactions = {
      chat = { adapter = "anthropic" },
      inline = { adapter = "anthropic" },
    },
  })
end

local loaded = false
local function ensure_loaded()
  if not loaded then
    load_codecompanion()
    loaded = true
  end
end

vim.api.nvim_create_user_command("CodeCompanion", function(opts)
  ensure_loaded()
  vim.cmd("CodeCompanion " .. opts.args)
end, { nargs = "*", range = true, desc = "CodeCompanion (lazy-loaded)" })

vim.api.nvim_create_user_command("CodeCompanionChat", function()
  ensure_loaded()
  vim.cmd("CodeCompanionChat")
end, { desc = "CodeCompanion chat (lazy-loaded)" })

vim.keymap.set({ "n", "v" }, "<leader>aa", "<cmd>CodeCompanionChat<cr>", { desc = "CodeCompanion chat" })
