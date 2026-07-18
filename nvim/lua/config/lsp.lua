-- Native LSP setup using vim.lsp.config()/vim.lsp.enable() (Neovim 0.11+).
-- nvim-lspconfig is not used here — as of Neovim 0.12 it's explicitly called
-- out as legacy, and its server tables are simple enough to inline for the
-- handful of servers you actually need.
--
-- Prereqs (install once, not managed by Neovim):
--   npm i -g @vtsls/language-server typescript vscode-langservers-extracted
--   brew install marksman   (or grab a release binary — see marksman repo)
--
-- vscode-langservers-extracted ships `vscode-eslint-language-server`, which
-- is what the "eslint" config below expects on $PATH.

local inlay_hints = {
	parameterNames = { enabled = "literals" },
	parameterTypes = { enabled = true },
	variableTypes = { enabled = true },
	propertyDeclarationTypes = { enabled = true },
	functionLikeReturnTypes = { enabled = true },
	enumMemberValues = { enabled = true },
}

vim.lsp.config("vtsls", {
	cmd = { "vtsls", "--stdio" },
	filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
	root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
	init_options = { hostInfo = "neovim" },
	settings = {
		typescript = { inlayHints = inlay_hints },
		javascript = { inlayHints = inlay_hints },
	},
})

vim.lsp.config("eslint", {
	cmd = { "vscode-eslint-language-server", "--stdio" },
	filetypes = {
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
	},
	root_markers = {
		"eslint.config.js",
		"eslint.config.mjs",
		".eslintrc.js",
		".eslintrc.json",
		"package.json",
		".git",
	},
	settings = {
		-- Flip to false if a project pins ESLint < 9 with a legacy .eslintrc.
		experimental = { useFlatConfig = true },
	},
})

vim.lsp.config("marksman", {
	cmd = { "marksman", "server" },
	filetypes = { "markdown", "markdown.mdx" },
	root_markers = { ".marksman.toml", ".git" },
})

vim.lsp.config("bashls", {
  cmd = { "bash-language-server", "start" },
  filetypes= { "sh", "bash" },
  root_markers = { ".git" },
  settings = {
    bashIde = {
      -- shellcheck is a separate binary this defers to for linting;
      -- without it on $PATH, bashls still runs, just without diagnostics.
      shellcheckPath = "shellcheck",
    },
  },
})

vim.lsp.enable({ "vtsls", "eslint", "marksman", "bashls" })

-- Shared on-attach keymaps -------------------------------------------------

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
	callback = function(args)
		local map = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
		end

		map("n", "gd", vim.lsp.buf.definition, "Go to definition")
		map("n", "gr", vim.lsp.buf.references, "References")
		map("n", "K", vim.lsp.buf.hover, "Hover docs")
		map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
		map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
		-- Formatting is owned by conform.nvim (see plugins/conform.lua, <leader>cf)
		-- so there's exactly one format path per buffer, not two competing ones.
	end,
})
