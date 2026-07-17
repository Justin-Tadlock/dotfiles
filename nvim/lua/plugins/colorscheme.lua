-- You didn't list a colorscheme as a "must-have," so this defaults to
-- Neovim's built-in `retrobox` (zero plugin, zero download). If you were
-- running something specific under LazyVim (tokyonight, catppuccin, etc.),
-- swap the block below — every popular scheme supports vim.pack the same way:
--
-- vim.pack.add({ "https://github.com/catppuccin/nvim" })
-- vim.cmd.colorscheme("catppuccin")

vim.pack.add({ "https://github.com/folke/tokyonight.nvim" })

--vim.cmd.colorscheme("retrobox")
vim.cmd.colorscheme("tokyonight-moon")
