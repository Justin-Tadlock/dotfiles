-- On Neovim 0.12, highlighting/indent via tree-sitter is on by default for
-- any filetype with a parser available — no plugin, no setup call. This file
-- exists only to fetch parsers that don't ship with core Neovim (TS/TSX/JSON/
-- YAML/etc.), using nvim-treesitter's current `main` branch as a thin
-- installer.

-- NOTE: the nvim-treesitter repo itself was archived (frozen, no further
-- updates) on April 3, 2026. It still works today — archived just means
-- read-only on GitHub, not broken — but it won't get fixes going forward.
-- If it ever stops working on a future Neovim release, the alternative is
-- a small purpose-built parser installer like tree-sitter-manager.nvim.

vim.pack.add({
	"https://github.com/nvim-treesitter/nvim-treesitter",
})

require("nvim-treesitter").install({
	"typescript",
	"tsx",
	"javascript",
	"json",
	"yaml",
	"markdown",
	"markdown_inline",
	"lua",
	"bash",
	"dockerfile",
	"go",
	"gomod",
	"gosum",
})

-- Belt-and-suspenders: explicitly start the highlighter on FileType in case
-- a parser isn't auto-attached for a given buffer.
vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		pcall(vim.treesitter.start, args.buf)
	end,
})
