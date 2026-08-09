-- Remove when intending to use local LLMs or an ACP LLM
if true then return {} end

return {
  "olimorris/codecompanion.nvim",
  keys = {
    {
      "<leader>ai",
      function() require("codecompanion").toggle() end,
      desc = "Toggle CodeCompanion CLI",
      mode = { "n", "v" },
    },
    {
      "<leader>aa",
      function() require("codecompanion").cli("#{this}", { focus = false }) end,
      desc = "Add current buffer/selection to CLI agent",
      mode = { "n", "v" },
    },
  },
  opts = {
    display = {
      chat = {
        window = {
          width = 0.35,
        },
      },
    },
    interactions = {
      chat = {
        adapter = "claude_code",
      },
      cli = {
        agent = "claude_code",
        agents = {
          claude_code = {
            cmd = "claude",
            args = {},
            description = "Claude Code CLI",
            provider = "terminal",
          },
        },
      },
    },
  },
}
