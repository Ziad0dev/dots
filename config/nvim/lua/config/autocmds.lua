local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

autocmd("TextYankPost", {
  group = augroup("reaper_highlight_yank", { clear = true }),
  callback = function()
    (vim.hl or vim.highlight).on_yank()
  end,
})

autocmd("BufReadPost", {
  group = augroup("reaper_restore_cursor", { clear = true }),
  callback = function(ev)
    if vim.b[ev.buf].reaper_restored then return end
    vim.b[ev.buf].reaper_restored = true
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

autocmd("FileType", {
  group = augroup("reaper_close_with_q", { clear = true }),
  pattern = {
    "help", "lspinfo", "qf", "checkhealth", "man", "aerial", "fugitive",
    "oil", "gitsigns-blame", "startuptime",
  },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})

autocmd("BufWritePre", {
  group = augroup("reaper_mkdir", { clear = true }),
  callback = function(ev)
    if ev.match:match("^%w%w+://") then return end
    vim.fn.mkdir(vim.fn.fnamemodify(vim.uv.fs_realpath(ev.match) or ev.match, ":p:h"), "p")
  end,
})

autocmd("VimResized", {
  group = augroup("reaper_resize", { clear = true }),
  callback = function()
    local tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tab)
  end,
})
