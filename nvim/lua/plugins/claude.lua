-- claudecode.nvim: bridges Neovim to the Claude Code CLI.
-- Requires the `claude` CLI installed and authenticated separately
-- (this plugin drives it, it doesn't ship it).
--
-- The exact setup table and default keymaps move fast on this plugin —
-- check https://github.com/coder/claudecode.nvim's README before relying
-- on anything below beyond the plugin being present and enabled.

vim.pack.add({
  "https://github.com/coder/claudecode.nvim",
})

require("claudecode").setup({})

vim.keymap.set("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude Code" })
