# nvim

Minimal Neovim config built on the native `vim.pack` plugin manager
(Neovim 0.12+, released March 29, 2026) instead of lazy.nvim, and on native
`vim.lsp.config`/`vim.lsp.enable` instead of `nvim-lspconfig`.

## Requirements

- **Neovim 0.12+** — `nvim --version`. On servers, don't rely on the distro's
  `vim`/`nvim` package; drop in a release tarball/AppImage from
  https://github.com/neovim/neovim/releases so the version and config are
  identical everywhere.
- **ripgrep** and **fzf** binaries on `$PATH` (used by `fzf-lua`)
- **lazygit** binary on `$PATH`
- **prettier** resolvable per project (local `node_modules` or global)
- LSP servers, installed independently of Neovim:
  ```
  npm i -g typescript typescript-language-server vscode-langservers-extracted
  ```
  plus `marksman` (release binary from its GitHub repo, or your package
  manager if it's packaged)
- **pandoc** binary on `$PATH` for the `:PandocTo*` commands
- **claude** CLI (for `claudecode.nvim`) and `ANTHROPIC_API_KEY` in the
  environment (for `codecompanion.nvim`'s anthropic adapter)

None of the above are vendored or auto-installed by this config on purpose —
per-machine binaries stay a provisioning concern (Ansible/cloud-init/your
`setup` script), not something Neovim's startup path should own.

## Layout

```
nvim/
├── init.lua                 -- leader keys, require() order
└── lua/
    ├── config/
    │   ├── 0_config.lua     -- options + non-plugin keymaps
    │   └── lsp.lua           -- native LSP servers + on-attach keymaps
    └── plugins/
        ├── colorscheme.lua
        ├── treesitter.lua    -- parser installer only; highlighting is native
        ├── fzf.lua
        ├── whichkey.lua
        ├── lazygit.lua       -- zero-plugin floating terminal
        ├── conform.lua       -- formatting (single owner: Prettier)
        ├── claude.lua        -- claudecode.nvim
        ├── codecompanion.lua -- lazy-loaded behind a user command
        └── pandoc.lua        -- no plugin, shells out to the pandoc binary
```

Symlink the whole `nvim/` directory to `~/.config/nvim` from your `setup`
script, same as the other tools in this repo.

## Notes / things that move fast

- `nvim-treesitter`'s old `master` branch API
  (`require('nvim-treesitter.configs').setup({...})`) is retired; that repo
  was archived and highlighting/indent now live in Neovim core. Only the
  `main` branch (parser installation) is used here.
- `claudecode.nvim` and `codecompanion.nvim` both iterate their config shape
  fairly often — if either throws an error on `setup()`, check the repo's
  README before assuming this file is stale in some other way.
- If you ever need a server stuck on Neovim 0.10/0.11 (pre-`vim.pack`), swap
  `vim.pack.add({...})` calls for `mini.deps`'s `add({...})` — same call
  shape, different manager underneath.
