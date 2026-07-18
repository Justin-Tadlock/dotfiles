-- conform.nvim: just runs formatters, nothing else. Prettier does the
-- actual formatting; ESLint's LSP handles lint-fixes separately via
-- <leader>ca (code action) if you want `eslint --fix`-equivalent behavior.
-- Requires `prettier` resolvable per-project (npx/local node_modules) or
-- globally on $PATH.

vim.pack.add({
  "https://github.com/stevearc/conform.nvim",
})

require("conform").setup({
  formatters_by_ft = {
    javascript = { "prettier" },
    javascriptreact = { "prettier" },
    typescript = { "prettier" },
    typescriptreact = { "prettier" },
    json = { "prettier" },
    jsonc = { "prettier" },
    css = { "prettier" },
    html = { "prettier" },
    yaml = { "prettier" },
    markdown = { "prettier" },
    sh = { "shfmt" },
    bash = { "shfmt" },
  },
  format_on_save = {
    timeout_ms = 1000,
    lsp_fallback = true,
  },
})

vim.keymap.set({ "n", "v" }, "<leader>cf", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format buffer (conform)" })
