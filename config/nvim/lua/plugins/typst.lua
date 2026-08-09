-- ============================================================================
-- Typst — no plugins. The LSP is registered in lsp.lua alongside every other
-- server; preview is a tinymist workspace command, so there is no binary for a
-- plugin manager to fetch and nothing here to install.
-- ============================================================================

local function client()
  return vim.lsp.get_clients({ bufnr = 0, name = "tinymist" })[1]
end

-- VERIFY ON YOUR BUILD if the keymap errors — the command name has moved
-- between releases (tinymist.doStartPreview / tinymist.startDefaultPreview):
--   :lua =client().server_capabilities.executeCommandProvider
local function preview_start()
  local c = client()
  if not c then
    vim.notify("tinymist is not attached to this buffer", vim.log.levels.WARN)
    return
  end
  c:exec_cmd({
    command = "tinymist.doStartPreview",
    arguments = { { "--open", vim.api.nvim_buf_get_name(0) } },
  }, { bufnr = 0 })
end

local function preview_stop()
  local c = client()
  if c then
    c:exec_cmd({ command = "tinymist.doKillPreview", arguments = {} }, { bufnr = 0 })
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("reaper_typst", { clear = true }),
  pattern = "typst",
  callback = function(ev)
    vim.opt_local.spell = true
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    local function m(keys, fn, desc)
      vim.keymap.set("n", keys, fn, { buffer = ev.buf, desc = "Typst: " .. desc })
    end
    m("<leader>dp", preview_start, "Start preview")
    m("<leader>dP", preview_stop, "Stop preview")
    m("<leader>dc", "<cmd>!typst compile %<cr>", "Compile once")
    m("<leader>df", function()
      vim.lsp.buf.format({ name = "tinymist" })
    end, "Format")
  end,
})

-- nvim 0.10+ detects .typ already; harmless safety net.
vim.filetype.add({ extension = { typ = "typst" } })

return {}
