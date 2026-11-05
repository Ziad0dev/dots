-- pdf.buffer — `nvim file.pdf` shows the text layer instead of binary noise.
--
-- The buffer is read-only; it exists so you can read, search and *select* text,
-- then act on it: visual-select + <leader>ph highlights that text in the real
-- PDF, <leader>pr redacts it, and <CR> opens the viewer on the current page.
local core = require("pdf.core")

local M = {}

--- 1-based page number for a buffer line (pdftotext starts each page after a ^L).
function M.page_at(buf, lnum)
  local page = 1
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, lnum, false)) do
    local _, n = line:gsub("\f", "")
    page = page + n
  end
  return page
end

local function jump_page(dir)
  local flags = dir > 0 and "W" or "bW"
  -- the line holding the form feed that starts a page
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local start = vim.fn.search("\\%x0c", flags .. "n")
  if dir < 0 and start >= cur then
    start = vim.fn.search("\\%x0c", "bWn")
  end
  if start > 0 then
    vim.api.nvim_win_set_cursor(0, { start, 0 })
  end
end

function M.load(buf, path)
  path = vim.fn.fnamemodify(path, ":p")
  if vim.fn.executable("pdftotext") == 0 then
    return core.notify("pdftotext (poppler-utils) is not installed", vim.log.levels.ERROR)
  end
  -- bounded: a huge or hostile PDF must not freeze the editor
  local res = vim.system({ "pdftotext", "-layout", path, "-" }, { text = true, timeout = 15000 }):wait()
  if res.code == 124 then
    res.stderr = "pdftotext timed out after 15s"
  end
  local lines
  if res.code ~= 0 then
    lines = { "cannot read " .. path, "", vim.trim(res.stderr or "") }
    if (res.stderr or ""):lower():match("password") then
      lines[#lines + 1] = "encrypted: decrypt it first with <leader>pL"
    end
  else
    lines = vim.split(res.stdout, "\n", { plain = true })
    if not res.stdout:match("%S") then
      lines = { "(no text layer — a scan?  <leader>pO runs OCR)" }
    end
  end

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "pdftext"
  vim.bo[buf].modifiable = true -- a reload (:e) arrives here already locked
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.b[buf].pdf_path = path
  core.last = path

  local function open_here()
    local page = M.page_at(buf, vim.api.nvim_win_get_cursor(0)[1])
    core.view(path, page)
  end
  local function m(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = "PDF: " .. desc })
  end
  m("<CR>", open_here, "Open in viewer at this page")
  m("o", open_here, "Open in viewer at this page")
  m("]]", function()
    jump_page(1)
  end, "Next page")
  m("[[", function()
    jump_page(-1)
  end, "Previous page")
  m("q", "<cmd>bdelete<cr>", "Close")

  vim.opt_local.wrap = false
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.list = false

  -- Open the viewer only when the user really opened this PDF: not for :Pdf text
  -- (core.skip_view), and not for background loads such as previews.
  local skip = core.skip_view
  core.skip_view = false
  if vim.g.pdf_view_on_open ~= false and not skip and not vim.b[buf].pdf_viewed then
    vim.b[buf].pdf_viewed = true
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf then
        core.view(path)
      end
    end)
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = vim.api.nvim_create_augroup("dots_pdf_buffer", { clear = true }),
    pattern = { "*.pdf", "*.PDF" },
    callback = function(ev)
      M.load(ev.buf, ev.match)
    end,
  })
end

return M
