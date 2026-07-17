-- fzf-lua wraps the `fzf` binary directly — no plenary.nvim, no telescope.nvim.
-- Requires: the `fzf` binary on $PATH (brew install fzf / apt install fzf),
-- and `ripgrep` for live_grep.

vim.pack.add({
	"https://github.com/ibhagwan/fzf-lua",
})

local fzf = require("fzf-lua")

fzf.setup({
	winopts = { height = 0.85, width = 0.90 },
})

local map = vim.keymap.set

-- Nearest ancestor containing a project marker. Falls back to cwd if none
-- are found (e.g., you're editing a scratch file with no git repo around it).
local function project_root()
	local root = vim.fs.root(0, { ".git", "package.json" })
	return root or vim.fn.getcwd()
end

map("n", "<leader>ff", function()
	fzf.files({ cwd = project_root() })
end, { desc = "Find files (project root)" })
map("n", "<leader>fg", fzf.live_grep, { desc = "Live grep" })
map("n", "<leader>fb", fzf.buffers, { desc = "Find buffers" })
map("n", "<leader>fo", fzf.oldfiles, { desc = "Recent files" })
map("n", "<leader>fw", fzf.grep_cword, { desc = "Grep word under cursor" })
map("n", "<leader>fh", fzf.helptags, { desc = "Help tags" })
