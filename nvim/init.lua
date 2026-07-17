-- ~/.config/nvim/init.lua (symlinked from dotfiles/nvim/init.lua)
--
-- Requires Neovim 0.12+ for vim.pack (native plugin manager) and the
-- expanded native LSP config surface. Check with `nvim --version`.
--
-- Load order matters:
--   1. leader keys (must be set before any plugin/keymap touches <leader>)
--   2. core options + keymaps
--   3. plugins (each file calls vim.pack.add itself)
--   4. lsp config (depends on nothing above except options)

-- Set the <leader> mods
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Set the core configs and keymaps
require("config.0_config")
require("config.lsp")

-- Set plugin specific configs and keymaps
require("plugins.colorscheme")
require("plugins.treesitter")
require("plugins.fzf")
require("plugins.whichkey")
require("plugins.lazygit")
require("plugins.conform")
require("plugins.claude")
--require("plugins.codecompanion")
require("plugins.pandoc")
require("plugins.buffertabs")
require("plugins.snacks")
