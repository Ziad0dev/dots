-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("reaper_highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Restore last cursor position
autocmd("BufReadPost", {
  group = augroup("reaper_restore_cursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close utility filetypes with q
autocmd("FileType", {
  group = augroup("reaper_close_with_q", { clear = true }),
  pattern = { "help", "lspinfo", "qf", "checkhealth", "man", "aerial", "fugitive" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})
