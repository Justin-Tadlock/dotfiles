-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<C-d>", "zz<C-d>", { desc = "Scroll down half page and center" })
vim.keymap.set("n", "<C-u>", "zz<C-u>", { desc = "Scroll up half page and center" })
