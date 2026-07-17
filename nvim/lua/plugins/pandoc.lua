-- Pandoc doesn't need a plugin — it's a conversion CLI, not an editor
-- integration. This just wires a couple of commands to shell out to it.
-- Requires the `pandoc` binary on $PATH. Markdown editing itself (folding,
-- LSP diagnostics/completion) is handled by marksman, configured in
-- config/lsp.lua — this file is only the doc-conversion convenience layer.

local function pandoc_to(target_ext)
  return function()
    local src = vim.fn.expand("%:p")
    if src == "" then
      vim.notify("No file to convert", vim.log.levels.WARN)
      return
    end
    local dest = vim.fn.expand("%:p:r") .. "." .. target_ext
    vim.system({ "pandoc", src, "-o", dest }, {}, function(res)
      vim.schedule(function()
        if res.code == 0 then
          vim.notify("Converted to " .. dest)
        else
          vim.notify("pandoc failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
        end
      end)
    end)
  end
end

vim.api.nvim_create_user_command("PandocToPdf", pandoc_to("pdf"), { desc = "Convert current file to PDF via pandoc" })
vim.api.nvim_create_user_command("PandocToDocx", pandoc_to("docx"), { desc = "Convert current file to docx via pandoc" })
vim.api.nvim_create_user_command("PandocToHtml", pandoc_to("html"), { desc = "Convert current file to HTML via pandoc" })
