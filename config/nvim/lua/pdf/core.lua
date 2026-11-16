-- pdf.core — run dots-pdf / dots-pdfsign, find the PDF to act on, show results.
local M = {}

local bin = { pdf = "dots-pdf", sign = "dots-pdfsign" }

---@type string|nil last PDF we acted on or produced (so operations chain)
M.last = nil
--- set just before loading a PDF buffer that must not pop open the viewer
M.skip_view = false
local viewer = nil

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "PDF" })
end

function M.is_pdf(path)
  return type(path) == "string" and path:lower():match("%.pdf$") ~= nil
end

local function exists(path)
  return path ~= nil and path ~= "" and vim.uv.fs_stat(path) ~= nil
end

local function trim(s)
  local r = (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return r
end

-- --- viewer --------------------------------------------------------------

--- Open `path` in zathura (optionally at a page). One viewer follows the work:
--- opening the next result closes the previous window we launched.
function M.view(path, page)
  if not exists(path) then
    return M.notify("no such file: " .. tostring(path), vim.log.levels.ERROR)
  end
  if vim.fn.executable("zathura") == 0 then
    return M.notify("zathura is not installed", vim.log.levels.ERROR)
  end
  if viewer then
    pcall(vim.fn.jobstop, viewer)
    viewer = nil
  end
  local cmd = { "zathura" }
  if page then
    vim.list_extend(cmd, { "-P", tostring(page) })
  end
  table.insert(cmd, path)
  viewer = vim.fn.jobstart(cmd, { detach = true })
end

-- --- running tools -------------------------------------------------------

--- Run a tool and call back with the vim.SystemCompleted result.
function M.run(tool, argv, opts, cb)
  opts = opts or {}
  local exe = bin[tool] or tool
  if vim.fn.executable(exe) == 0 then
    return M.notify(exe .. " not found. Rebuild home-manager (home/documents.nix installs it).", vim.log.levels.ERROR)
  end
  local cmd = { exe }
  vim.list_extend(cmd, argv)
  vim.system(cmd, { text = true, env = opts.env, cwd = opts.cwd }, vim.schedule_wrap(cb))
end

local function last_line(s)
  local out
  for line in (s or ""):gmatch("[^\r\n]+") do
    out = line
  end
  return out
end

--- Run a tool that produces a file. Notifies, remembers the result and (for
--- PDFs) shows it. opts: label, env, view=false to skip the viewer, done(path).
function M.exec(tool, argv, opts)
  opts = opts or {}
  M.run(tool, argv, opts, function(res)
    local out = trim(last_line(res.stdout))
    if res.code ~= 0 then
      local msg = trim(res.stderr ~= "" and res.stderr or res.stdout)
      return M.notify((opts.label or "failed") .. ":\n" .. msg, vim.log.levels.ERROR)
    end
    if M.is_pdf(out) and exists(out) then
      M.last = vim.fn.fnamemodify(out, ":p")
      if opts.view ~= false and vim.g.pdf_autoview ~= false then
        M.view(M.last)
      end
    end
    M.notify(("%s → %s"):format(opts.label or "done", out ~= "" and out or "ok"))
    if opts.done then
      opts.done(out, res)
    end
  end)
end

-- --- scratch output ------------------------------------------------------

function M.scratch(title, lines, ft)
  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = ft or "text"
  pcall(vim.api.nvim_buf_set_name, buf, "[pdf] " .. title)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
  return buf
end

--- Run a tool and show its output in a scratch split.
function M.show(tool, argv, title, ft)
  M.run(tool, argv, {}, function(res)
    local text = res.stdout ~= "" and res.stdout or res.stderr
    if res.code ~= 0 and res.stdout == "" then
      return M.notify(trim(res.stderr), vim.log.levels.ERROR)
    end
    M.scratch(title, vim.split(trim(text), "\n", { plain = true }), ft)
  end)
end

-- --- prompts -------------------------------------------------------------

function M.input(prompt, default, completion, cb)
  vim.ui.input({ prompt = prompt, default = default or "", completion = completion }, function(v)
    if v ~= nil then
      cb(v)
    end
  end)
end

function M.select(items, opts, cb)
  vim.ui.select(items, opts, function(item, idx)
    if item ~= nil then
      cb(item, idx)
    end
  end)
end

--- Ask a list of questions in order. field = { key, prompt, default, completion,
--- choices = { ... } }. A field whose `when(values)` is false is skipped.
function M.ask(fields, cb)
  local values = {}
  local function step(i)
    local f = fields[i]
    if not f then
      return cb(values)
    end
    if f.when and not f.when(values) then
      return step(i + 1)
    end
    local default = type(f.default) == "function" and f.default(values) or f.default
    if f.choices then
      M.select(f.choices, { prompt = f.prompt }, function(v)
        values[f.key] = v
        step(i + 1)
      end)
    else
      M.input(f.prompt, default, f.completion, function(v)
        values[f.key] = trim(v)
        step(i + 1)
      end)
    end
  end
  step(1)
end

-- --- which PDF? ----------------------------------------------------------

local function oil_pdf()
  local ok, oil = pcall(require, "oil")
  if not ok or vim.bo.filetype ~= "oil" then
    return nil
  end
  local entry = oil.get_cursor_entry()
  local dir = oil.get_current_dir()
  if entry and dir and M.is_pdf(entry.name) then
    return dir .. entry.name
  end
end

local function vimtex_pdf()
  if not vim.b.vimtex then
    return nil
  end
  local ok, out = pcall(vim.fn.eval, "b:vimtex.out()")
  if ok and exists(out) then
    return out
  end
end

local function sibling_pdf()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return nil
  end
  local pdf = vim.fn.fnamemodify(name, ":r") .. ".pdf"
  if pdf ~= name and exists(pdf) then
    return pdf
  end
end

local function find_pdfs()
  local found = vim.fs.find(function(name)
    return name:lower():match("%.pdf$") ~= nil
  end, { path = vim.uv.cwd(), limit = 200, type = "file" })
  table.sort(found)
  return found
end

--- Resolve the PDF to act on, then call cb(path). Order: a PDF buffer, the oil
--- entry under the cursor, the file vimtex built, a same-named sibling, then a
--- picker over PDFs below the working directory.
function M.target(cb)
  local name = vim.api.nvim_buf_get_name(0)
  local path = vim.b.pdf_path
    or (M.is_pdf(name) and exists(name) and name)
    or oil_pdf()
    or vimtex_pdf()
    or sibling_pdf()
  if path then
    path = vim.fn.fnamemodify(path, ":p")
    M.last = path
    return cb(path)
  end
  M.pick("PDF", function(p)
    M.last = vim.fn.fnamemodify(p, ":p")
    cb(M.last)
  end)
end

--- Pick any PDF below the working directory (or type a path if there are none).
function M.pick(prompt, cb)
  local pdfs = find_pdfs()
  if #pdfs == 0 then
    return M.input(prompt .. " file: ", M.last or "", "file", function(v)
      v = vim.fn.expand(v)
      if exists(v) then
        cb(vim.fn.fnamemodify(v, ":p"))
      else
        M.notify("no such file: " .. v, vim.log.levels.ERROR)
      end
    end)
  end
  M.select(pdfs, {
    prompt = prompt,
    format_item = function(p)
      return vim.fn.fnamemodify(p, ":~:.")
    end,
  }, cb)
end

--- Selected text (visual mode) collapsed to one line, or nil.
function M.selection()
  local mode = vim.fn.mode()
  if not mode:match("^[vV\22]") then
    return nil
  end
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  local text = trim((table.concat(lines, " "):gsub("%s+", " ")))
  return text ~= "" and text or nil
end

return M
