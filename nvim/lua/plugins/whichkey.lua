vim.pack.add({
  "https://github.com/folke/which-key.nvim",
})

local wk = require("which-key")

wk.setup({
  preset = "modern",
})

-- Group labels shown in the which-key popup (v3 API)
wk.add({
  { "<leader>f", group = "find" },
  { "<leader>c", group = "code" },
  { "<leader>g", group = "git" },
  { "<leader>b", group = "buffer" },
  { "<leader>a", group = "ai (claude/codecompanion)" },
})
