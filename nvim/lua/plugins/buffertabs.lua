-- Emulates LazyVim's "tabs at top showing open buffers." Neovim's own
-- 'tabline' option renders actual :tabnew tabs, not buffers -- there's no
-- native way to show buffers-as-tabs, so this genuinely needs a plugin
-- rather than a config tweak. akinsho/bufferline.nvim is going to be used.
-- 
-- Owns <S-h>/<S-l> instead of config/0_config.lua so buffer-cycling follows
-- the bufferline's visual left-to-right order, matching what's on screen,
-- rather than plain buffer-number order.

vim.pack.add({
  "https://github.com/akinsho/bufferline.nvim",
})

require("bufferline").setup({
  options = {
    mode = "buffers",
    show_buffer_icons = false,
    show_buffer_close_icons = true,
    show_close_icon = false,
    diagnostics = "nvim_lsp",
  },
})

vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
