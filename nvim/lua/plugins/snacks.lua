-- snacks.nvim is a required dependency of claudecode.nvim (coder/claudecode.nvim,
-- see plugins/claude.lua) for its terminal integration. Rather than adopt
-- LazyVim's full snacks setup, only what you actually asked for is enabled
-- here: the file explorer and a terminal toggle. Everything else is
-- explicitly disabled below, rather than left to whatever snacks' own
-- defaults happen to be.
--
-- One wrinkle: snacks' explorer is implemented as a picker source ("a picker
-- in disguise" per its own docs), so `picker` has to be enabled for the
-- explorer to work at all -- that's not scope creep, it's how it's built.
-- This does NOT wire up snacks' picker for fuzzy-finding files/grep -- fzf-lua
-- already owns that job (plugins/fzf.lua). No picker keymaps are set here,
-- so the two engines never compete for the same keys.

vim.pack.add({
  "https://github.com/folke/snacks.nvim",
})

require("snacks").setup({
  -- Explicitly off: everything not asked for, rather than trusting defaults.
  bigfile = { enabled = false },
  dashboard = { enabled = false },
  indent = { enabled = false },
  input = { enabled = false },
  notifier = { enabled = false },
  quickfile = { enabled = false },
  scope = { enabled = false },
  scroll = { enabled = false },
  statuscolumn = { enabled = false },
  words = { enabled = false },
  animate = { enabled = false },
  image = { enabled = false },
  zen = { enabled = false },
  toggle = { enabled = false },
  explorer = { enabled = true },
  picker = {
    enabled = true, -- required for explorer to function; no fuzzy-find keymaps set
    sources = {
      explorer = {
        auto_close = true,
      },
    },
  },
  terminal = { enabled = true },
})

-- Custom functions
local function toggleTerminal()
  Snacks.terminal()
end

-- Keymaps
vim.keymap.set("n", "<leader>e", function()
  Snacks.explorer()
end, { desc = "File explorer" })

vim.keymap.set({ "n", "t" }, "<C-_>", toggleTerminal, { desc = "Toggle terminal" })
vim.keymap.set({ "n", "t" }, "<C-/>", toggleTerminal, { desc = "Toggle terminal" })
