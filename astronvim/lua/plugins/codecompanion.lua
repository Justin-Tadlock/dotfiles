return {
  "olimorris/codecompanion.nvim",
  opts = {
    adapters = {
      acp = {
        claude_code = function()
          return require("codecompanion.adapters").extend("claude_code", {
            commands = {
              default = { "claude-agent-acp", "--acp" },
            },
            env = {
              CLAUDE_AUTH_TOKEN = "cmd:echo ${CLAUDE_AUTH_TOKEN}",
            },
          })
        end,
      },
    },
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
    },
  },
}
