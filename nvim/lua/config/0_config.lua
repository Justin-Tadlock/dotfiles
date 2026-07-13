if vim.loader then
	vim.loader.enable()
end

-- I don't like having a split clipboard buffer from system and different nvim buffers
-- Note: if the clipboard is not merging with the system, install one of the following:
-- Wayland Displays: wl-clipboard
-- X11 displays: xclip or xsel
vim.schedule(function()
	vim.o.clipboard = "unnamedplus"
end)

-- Sometimes I'm lazy and just use the mouse..
vim.o.mouse = "a"

-- Disable relative numbers in favor of #G navigation
vim.o.relativenumber = false

vim.o.breakindent = true
vim.o.undofile = true

-- Search case-insensitive by default unless a Casing was used
vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.signcolumn = "yes"
vim.o.inccommand = "split"
vim.o.cursorline = true
vim.o.confirm = true
