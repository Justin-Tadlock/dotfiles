-- LazyGit doesn't need a plugin: it's a full-screen TUI that already
-- manages its own drawing, so a plain floating terminal buffer is enough.
-- Requires the `lazygit` binary on $PATH.
--
-- If you'd rather have a maintained wrapper (auto-closes on quit, resize
-- handling, etc.), swap this whole file for:
--   vim.pack.add({ "https://github.com/kdheepak/lazygit.nvim" })
--   vim.keymap.set("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })

local function open_lazygit()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })

  vim.fn.jobstart("lazygit", {
    term = true,
    on_exit = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })

  vim.cmd.startinsert()
  vim.keymap.set("t", "<esc>", "<c-\\><c-n><cmd>q<cr>", { buffer = buf })
end

vim.keymap.set("n", "<leader>gg", open_lazygit, { desc = "LazyGit" })
