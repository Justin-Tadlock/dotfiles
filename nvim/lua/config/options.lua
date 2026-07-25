-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Core options and keymaps. No plugin dependencies belong in this file --
-- if a keymap needs a plugin's function, it lives in that plugin's own file.

if vim.loader then
  vim.loader.enable()
end

local opt = vim.opt

-- Deferred: setting `clipboard` triggers a synchronous call-out to
-- xclip/wl-copy/etc. to detect a provider. Wrapping in vim.schedule keeps
-- that off the startup hot path.
-- Note: if the clipboard doesn't merge with the system clipboard, install
-- wl-clipboard (Wayland) or xclip/xsel (X11).
vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)

-- UI
opt.number = true
opt.relativenumber = false -- using #G navigation instead
opt.signcolumn = "yes"
opt.cursorline = true
opt.termguicolors = true
opt.scrolloff = 8
opt.splitright = true
opt.splitbelow = true
opt.breakindent = true
opt.inccommand = "split"
opt.confirm = true
opt.mouse = "a"

-- Indentation (2-space, matches Next.js/TS/Prettier defaults)
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true

-- Files / undo
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.undodir = vim.fn.stdpath("state") .. "/undo"

-- Behavior
opt.updatetime = 250 -- faster diagnostic/CursorHold events
opt.timeoutlen = 400 -- affects which-key responsiveness
opt.wrap = false

-- Diagnostics: virtual text off by default, use a keymap to view a float
-- instead of a permanent inline wall of text (keeps things quiet on servers
-- with noisy linters).
vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})
