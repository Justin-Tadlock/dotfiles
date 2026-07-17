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

-- Core keymaps -----------------------------------------------------------

local map = vim.keymap.set

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })

-- Buffers
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
map("n", "<leader>bo", function()
  local current = vim.api.nvim_get_current_buf()
  local closed, skipped = 0, 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
      if vim.bo[buf].modified then
        skipped = skipped + 1
      else
        vim.api.nvim_buf_delete(buf, {})
        closed = closed + 1
      end
    end
  end
  local msg = string.format("Closed %d other buffer(s)", closed)
  if skipped > 0 then
    msg = msg .. string.format(" (%d skipped: unsaved changes)", skipped)
  end
  vim.notify(msg)
end, { desc = "Close other buffers" })

-- Diagnostics
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show line diagnostics" })
map("n", "[d", function()
	vim.diagnostic.jump({ count = -1 })
end, { desc = "Prev diagnostic" })
map("n", "]d", function()
	vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })

-- Clear search highlight
map("n", "<esc>", "<cmd>nohlsearch<cr>")

-- Keep visual selection after indent
map("v", "<", "<gv")
map("v", ">", ">gv")
