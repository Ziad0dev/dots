-- pdf — an Acrobat-shaped toolbox inside Neovim.
--
--   :Pdf              menu of every tool        (<leader>pp)
--   :Pdf <tool>       run one                   (:Pdf sign, :Pdf redact, ...)
--   :Pdf raw <args>   straight to `dots-pdf`
--
-- All edits are written to a NEW file beside the original (never in place) and
-- the result opens in the viewer, so tools chain: highlight, fill, sign, ...
-- Engines live in scripts/dots-pdf*.{sh,js}; this file is only the UI.
local core = require("pdf.core")
local sign = require("pdf.sign")

local M = {}

local function pdf_cmd(args, label, opts)
  opts = opts or {}
  opts.label = label
  core.exec("pdf", args, opts)
end

local function split_words(s)
  local out = {}
  for w in s:gmatch("%S+") do
    out[#out + 1] = w
  end
  return out
end

local function state_image()
  local p = (vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")) .. "/dots/pdfsign/signature.png"
  return vim.uv.fs_stat(p) and p or ""
end

--- Export JSON next to the cache, open it for editing, and apply it on every :w.
local function edit_json(pdf, export_args, apply_args, label, hint)
  local dir = vim.fn.stdpath("cache") .. "/pdf"
  vim.fn.mkdir(dir, "p")
  local json = ("%s/%s.%s.json"):format(dir, vim.fn.fnamemodify(pdf, ":t:r"), (label:gsub("%s+", "-")))
  vim.uv.fs_unlink(json)
  local argv = vim.list_extend({}, export_args)
  vim.list_extend(argv, { "-o", json })
  core.run("pdf", argv, {}, function(res)
    if res.code ~= 0 or not vim.uv.fs_stat(json) then
      return core.notify(vim.trim(res.stderr ~= "" and res.stderr or res.stdout), vim.log.levels.ERROR)
    end
    vim.cmd("botright split " .. vim.fn.fnameescape(json))
    local buf = vim.api.nvim_get_current_buf()
    core.notify(hint)
    local group = vim.api.nvim_create_augroup("dots_pdf_json_" .. buf, { clear = true })
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = group,
      buffer = buf,
      callback = function()
        pdf_cmd(apply_args(json), label)
      end,
    })
  end)
end

-- --- actions -------------------------------------------------------------
-- { id, label, run = function(pdf, sel) } ; sel is the visual selection, if any

local function mark(kind, label, default_color)
  return function(pdf, sel)
    local function go(term)
      pdf_cmd({ kind, pdf, "--", term, default_color, "all" }, label)
    end
    if sel then
      go(sel)
    else
      core.input(label .. " text: ", "", nil, function(t)
        if t ~= "" then
          go(t)
        end
      end)
    end
  end
end

local COLORS = { "yellow", "green", "blue", "pink", "orange", "red", "purple" }

local actions = {
  {
    id = "view",
    label = "Open in viewer",
    run = function(pdf)
      core.view(pdf)
    end,
  },

  -- signing
  {
    id = "sign",
    label = "Sign (digital signature)",
    run = function(pdf, sel)
      sign.sign(pdf, sel)
    end,
  },
  {
    id = "verify",
    label = "Verify signatures",
    run = function(pdf)
      sign.verify(pdf)
    end,
  },
  {
    id = "sign-image",
    label = "Set handwritten signature image",
    run = function()
      sign.image()
    end,
  },
  {
    id = "sign-setup",
    label = "Create signing certificate",
    run = function()
      sign.init()
    end,
  },
  {
    id = "sign-import",
    label = "Import a real certificate (.p12)",
    run = function()
      sign.import()
    end,
  },
  {
    id = "sign-status",
    label = "Show signing identity",
    run = function()
      sign.status()
    end,
  },

  -- read
  {
    id = "info",
    label = "Document info, signatures, forms",
    run = function(pdf)
      core.show("pdf", { "info", pdf }, "info: " .. vim.fn.fnamemodify(pdf, ":t"))
    end,
  },
  {
    id = "text",
    label = "Read as text (selectable)",
    run = function(pdf)
      core.skip_view = true
      vim.cmd("vsplit " .. vim.fn.fnameescape(pdf))
    end,
  },
  {
    id = "grep",
    label = "Search text",
    run = function(pdf)
      core.input("Search: ", "", nil, function(pat)
        if pat == "" then
          return
        end
        core.run("pdf", { "grep", pdf, "--", pat }, {}, function(res)
          local hits = {}
          for line in (res.stdout or ""):gmatch("[^\r\n]+") do
            local page, text = line:match("^(%d+):(.*)$")
            if page then
              hits[#hits + 1] = { page = tonumber(page), text = vim.trim(text) }
            end
          end
          if #hits == 0 then
            return core.notify("no match for " .. pat, vim.log.levels.WARN)
          end
          core.select(hits, {
            prompt = ("%d match(es)"):format(#hits),
            format_item = function(h)
              return ("p.%-3d %s"):format(h.page, h.text)
            end,
          }, function(h)
            core.view(pdf, h.page)
          end)
        end)
      end)
    end,
  },
  {
    id = "compare",
    label = "Compare with another PDF (diff)",
    run = function(pdf)
      core.pick("Compare with", function(other)
        local dir = vim.fn.stdpath("cache") .. "/pdf"
        vim.fn.mkdir(dir, "p")
        local a, b =
          dir .. "/a-" .. vim.fn.fnamemodify(pdf, ":t") .. ".txt",
          dir .. "/b-" .. vim.fn.fnamemodify(other, ":t") .. ".txt"
        vim.fn.system({ "pdftotext", "-layout", pdf, a })
        vim.fn.system({ "pdftotext", "-layout", other, b })
        vim.cmd("tabnew " .. vim.fn.fnameescape(a))
        vim.cmd("vert diffsplit " .. vim.fn.fnameescape(b))
      end)
    end,
  },

  -- mark up
  { id = "highlight", label = "Highlight", run = mark("highlight", "highlight", "yellow") },
  { id = "underline", label = "Underline", run = mark("underline", "underline", "blue") },
  { id = "strike", label = "Strike through", run = mark("strike", "strike through", "red") },
  { id = "squiggly", label = "Squiggly underline", run = mark("squiggly", "squiggly underline", "red") },
  {
    id = "highlight-colour",
    label = "Highlight (choose colour)",
    run = function(pdf, sel)
      local function go(term)
        core.select(COLORS, { prompt = "Colour" }, function(c)
          pdf_cmd({ "highlight", pdf, "--", term, c, "all" }, "highlight")
        end)
      end
      if sel then
        go(sel)
      else
        core.input("Highlight text: ", "", nil, function(t)
          if t ~= "" then
            go(t)
          end
        end)
      end
    end,
  },
  {
    id = "note",
    label = "Add sticky note",
    run = function(pdf)
      core.ask({
        { key = "page", prompt = "Page: ", default = "1" },
        { key = "x", prompt = "x (points from left): ", default = "72" },
        { key = "y", prompt = "y (points from bottom): ", default = "700" },
        { key = "text", prompt = "Note: " },
      }, function(v)
        pdf_cmd({ "note", pdf, "--", v.page, v.x, v.y, v.text }, "note")
      end)
    end,
  },
  {
    id = "fill",
    label = "Add text (fill & sign)",
    run = function(pdf, sel)
      core.ask({
        { key = "anchor", prompt = "Place after text (empty = coordinates): ", default = sel or "" },
        {
          key = "page",
          prompt = "Page: ",
          default = "1",
          when = function(v)
            return v.anchor == ""
          end,
        },
        {
          key = "x",
          prompt = "x (points from left): ",
          default = "72",
          when = function(v)
            return v.anchor == ""
          end,
        },
        {
          key = "y",
          prompt = "y (points from bottom): ",
          default = "700",
          when = function(v)
            return v.anchor == ""
          end,
        },
        { key = "size", prompt = "Font size: ", default = "11" },
        { key = "text", prompt = "Text: " },
      }, function(v)
        if v.text == "" then
          return
        end
        if v.anchor ~= "" then
          pdf_cmd({ "text-add", pdf, "--", "--after", v.anchor, v.size, v.text }, "text added")
        else
          pdf_cmd({ "text-add", pdf, "--", v.page, v.x, v.y, v.size, v.text }, "text added")
        end
      end)
    end,
  },
  {
    id = "image",
    label = "Place image / ink signature",
    run = function(pdf, sel)
      core.ask({
        { key = "img", prompt = "Image (png/jpg): ", default = state_image(), completion = "file" },
        { key = "anchor", prompt = "Place after text (empty = coordinates): ", default = sel or "" },
        {
          key = "page",
          prompt = "Page: ",
          default = "1",
          when = function(v)
            return v.anchor == ""
          end,
        },
        {
          key = "x",
          prompt = "x (points from left): ",
          default = "72",
          when = function(v)
            return v.anchor == ""
          end,
        },
        {
          key = "y",
          prompt = "y (points from bottom): ",
          default = "100",
          when = function(v)
            return v.anchor == ""
          end,
        },
        { key = "width", prompt = "Width (points): ", default = "150" },
      }, function(v)
        local img = vim.fn.expand(v.img)
        if v.anchor ~= "" then
          pdf_cmd({ "image", pdf, img, "--", "--after", v.anchor, v.width }, "image placed")
        else
          pdf_cmd({ "image", pdf, img, v.page, v.x, v.y, v.width }, "image placed")
        end
      end)
    end,
  },
  {
    id = "redact",
    label = "Redact (permanently remove text)",
    run = function(pdf, sel)
      local function go(term)
        local choice = vim.fn.confirm(
          ("Permanently remove “%s” everywhere?\n(written to a new file; the original is untouched)"):format(term),
          "&Redact\n&Cancel",
          2
        )
        if choice == 1 then
          pdf_cmd({ "redact", pdf, "--text", "--", term }, "redacted")
        end
      end
      if sel then
        go(sel)
      else
        core.input("Redact text: ", "", nil, function(t)
          if t ~= "" then
            go(t)
          end
        end)
      end
    end,
  },

  -- organise
  {
    id = "merge",
    label = "Merge PDFs",
    run = function(pdf)
      core.input("PDFs to merge, in order: ", pdf .. " ", "file", function(v)
        local files = split_words(v)
        if #files < 2 then
          return core.notify("need at least two files", vim.log.levels.WARN)
        end
        local args = { "merge" }
        vim.list_extend(args, vim.tbl_map(vim.fn.expand, files))
        pdf_cmd(args, "merged")
      end)
    end,
  },
  {
    id = "extract",
    label = "Extract pages",
    run = function(pdf)
      core.input("Pages to keep (1-3,5,z): ", "", nil, function(r)
        pdf_cmd({ "extract", pdf, r }, "extracted")
      end)
    end,
  },
  {
    id = "delete",
    label = "Delete pages",
    run = function(pdf)
      core.input("Pages to delete (2,4-5): ", "", nil, function(r)
        pdf_cmd({ "delete", pdf, r }, "pages deleted")
      end)
    end,
  },
  {
    id = "reorder",
    label = "Reorder pages",
    run = function(pdf)
      core.input("New order (3,1,2,4-z): ", "", nil, function(r)
        pdf_cmd({ "reorder", pdf, r }, "reordered")
      end)
    end,
  },
  {
    id = "rotate",
    label = "Rotate pages",
    run = function(pdf)
      core.ask({
        { key = "deg", prompt = "Rotate", choices = { "90", "180", "270" } },
        { key = "range", prompt = "Pages (empty = all): ", default = "" },
      }, function(v)
        local args = { "rotate", pdf, v.deg }
        if v.range ~= "" then
          args[#args + 1] = v.range
        end
        pdf_cmd(args, "rotated")
      end)
    end,
  },
  {
    id = "split",
    label = "Split into separate files",
    run = function(pdf)
      core.input("Pages per file: ", "1", nil, function(n)
        pdf_cmd({ "split", pdf, n }, "split", { view = false })
      end)
    end,
  },
  {
    id = "crop",
    label = "Crop pages",
    run = function(pdf)
      core.input("Crop ('20' = 20 mm margin, '[x1 y1 x2 y2]' = box): ", "20", nil, function(d)
        pdf_cmd({ "crop", pdf, d }, "cropped")
      end)
    end,
  },
  {
    id = "number",
    label = "Add page numbers",
    run = function(pdf)
      core.input("Format: ", "Page %p of %P", nil, function(f)
        pdf_cmd({ "number", pdf, "--", f }, "numbered")
      end)
    end,
  },
  {
    id = "watermark",
    label = "Add watermark",
    run = function(pdf)
      core.input("Watermark text: ", "CONFIDENTIAL", nil, function(t)
        pdf_cmd({ "watermark", pdf, "--", t }, "watermarked")
      end)
    end,
  },

  -- forms
  {
    id = "form",
    label = "Fill form fields (edit JSON, :w to apply)",
    run = function(pdf)
      edit_json(pdf, { "form", "export", pdf, "--force" }, function(json)
        return { "form", "fill", pdf, json }
      end, "form filled", "Edit the values, then :w to write a filled copy")
    end,
  },
  {
    id = "flatten",
    label = "Flatten forms & annotations",
    run = function(pdf)
      pdf_cmd({ "flatten", pdf }, "flattened")
    end,
  },
  {
    id = "bookmarks",
    label = "Edit bookmarks (JSON, :w to apply)",
    run = function(pdf)
      edit_json(pdf, { "bookmarks", "export", pdf, "--force" }, function(json)
        return { "bookmarks", "import", pdf, json }
      end, "bookmarks set", "Edit the outline, then :w to write a copy with these bookmarks")
    end,
  },

  -- document
  {
    id = "compress",
    label = "Compress",
    run = function(pdf)
      core.select({ "screen", "ebook", "printer", "prepress" }, { prompt = "Quality (screen = smallest)" }, function(l)
        pdf_cmd({ "compress", pdf, l }, "compressed")
      end)
    end,
  },
  {
    id = "optimize",
    label = "Optimise for web",
    run = function(pdf)
      pdf_cmd({ "optimize", pdf }, "optimised")
    end,
  },
  {
    id = "ocr",
    label = "OCR (make scans searchable)",
    run = function(pdf)
      core.notify("running OCR…")
      pdf_cmd({ "ocr", pdf }, "ocr done")
    end,
  },
  {
    id = "lock",
    label = "Password-protect",
    run = function(pdf)
      core.select(
        { "Password only", "No printing", "No copying", "No modification", "No printing, copying or modification" },
        { prompt = "Restrictions" },
        function(r)
          local flags = {
            ["Password only"] = {},
            ["No printing"] = { "--no-print" },
            ["No copying"] = { "--no-copy" },
            ["No modification"] = { "--no-modify" },
            ["No printing, copying or modification"] = { "--no-print", "--no-copy", "--no-modify" },
          }
          local pass = vim.fn.inputsecret("Password to open the file (empty = none): ")
          local args = { "encrypt", pdf }
          vim.list_extend(args, flags[r])
          pdf_cmd(args, "locked", { env = { DOTS_PDF_PASS = pass } })
        end
      )
    end,
  },
  {
    id = "unlock",
    label = "Remove password",
    run = function(pdf)
      local pass = vim.fn.inputsecret("Password: ")
      pdf_cmd({ "decrypt", pdf }, "unlocked", { env = { DOTS_PDF_PASS = pass } })
    end,
  },
  {
    id = "meta",
    label = "Edit metadata",
    run = function(pdf)
      core.select({ "Title", "Author", "Subject", "Keywords", "Strip all metadata" }, { prompt = "Field" }, function(f)
        if f:match("^Strip") then
          return pdf_cmd({ "meta", pdf, "--strip" }, "metadata stripped")
        end
        core.input(f .. ": ", "", nil, function(v)
          pdf_cmd({ "meta", pdf, f .. "=" .. v }, "metadata set")
        end)
      end)
    end,
  },
  {
    id = "attach",
    label = "Attachments (add / list / extract)",
    run = function(pdf)
      core.select({ "add", "list", "extract" }, { prompt = "Attachments" }, function(what)
        if what == "list" then
          core.show("pdf", { "attach", "list", pdf }, "attachments")
        elseif what == "extract" then
          pdf_cmd({ "attach", "extract", pdf }, "extracted", { view = false })
        else
          core.input("Files to attach: ", "", "file", function(v)
            local args = { "attach", "add", pdf }
            vim.list_extend(args, vim.tbl_map(vim.fn.expand, split_words(v)))
            pdf_cmd(args, "attached")
          end)
        end
      end)
    end,
  },

  -- convert
  {
    id = "to-images",
    label = "Export pages as images",
    run = function(pdf)
      core.select({ "png", "jpg" }, { prompt = "Format" }, function(fmt)
        core.input("DPI: ", "150", nil, function(dpi)
          pdf_cmd({ "to-images", pdf, fmt, dpi }, "exported", { view = false })
        end)
      end)
    end,
  },
  {
    id = "from-images",
    label = "Images → PDF",
    run = function()
      core.input("Images (space separated): ", "", "file", function(v)
        local args = { "from-images" }
        vim.list_extend(args, vim.tbl_map(vim.fn.expand, split_words(v)))
        pdf_cmd(args, "created")
      end)
    end,
  },
  {
    id = "from-office",
    label = "Word/Excel/PowerPoint → PDF (needs LibreOffice)",
    run = function()
      core.input("Document: ", "", "file", function(v)
        pdf_cmd({ "from-office", vim.fn.expand(v) }, "converted")
      end)
    end,
  },

  -- GUI handoff
  {
    id = "annotate",
    label = "Draw / ink annotate (Xournal++)",
    run = function(pdf)
      pdf_cmd({ "gui", "annotate", pdf }, "xournal++", { view = false })
    end,
  },
  {
    id = "arrange",
    label = "Arrange pages by drag & drop (PDF Arranger)",
    run = function(pdf)
      pdf_cmd({ "gui", "arrange", pdf }, "pdfarranger", { view = false })
    end,
  },
  {
    id = "edit",
    label = "Edit existing text/objects (LibreOffice Draw)",
    run = function(pdf)
      pdf_cmd({ "gui", "edit", pdf }, "libreoffice draw", { view = false })
    end,
  },
}

local by_id = {}
for _, a in ipairs(actions) do
  by_id[a.id] = a
end

--- Run an action by id on the current target PDF.
function M.run(id, sel)
  local a = by_id[id]
  if not a then
    return core.notify("unknown tool: " .. tostring(id), vim.log.levels.ERROR)
  end
  -- tools that need no document
  if id:match("^sign%-") or id == "from-images" or id == "from-office" then
    return a.run(nil, sel)
  end
  core.target(function(pdf)
    a.run(pdf, sel)
  end)
end

function M.menu()
  core.select(actions, {
    prompt = "PDF tools",
    format_item = function(a)
      return a.label
    end,
  }, function(a)
    M.run(a.id)
  end)
end

-- --- wiring --------------------------------------------------------------

local KEYS = {
  p = "menu",
  v = "view",
  s = "sign",
  V = "verify",
  k = "sign-setup",
  K = "sign-image",
  i = "info",
  t = "text",
  g = "grep",
  C = "compare",
  h = "highlight",
  H = "highlight-colour",
  u = "underline",
  x = "strike",
  n = "note",
  f = "fill",
  I = "image",
  r = "redact",
  m = "merge",
  e = "extract",
  d = "delete",
  o = "reorder",
  R = "rotate",
  c = "compress",
  O = "ocr",
  l = "lock",
  L = "unlock",
  w = "watermark",
  N = "number",
  F = "form",
  M = "meta",
  b = "bookmarks",
  a = "attach",
  T = "to-images",
  G = "annotate",
  A = "arrange",
  E = "edit",
}

-- these also work on a visual selection (the selected text is the search term / anchor)
local VISUAL = { s = true, h = true, H = true, u = true, x = true, f = true, I = true, r = true }

function M.setup()
  require("pdf.buffer").setup()

  vim.api.nvim_create_user_command("Pdf", function(opts)
    local sub = opts.fargs[1]
    if not sub then
      return M.menu()
    end
    if sub == "raw" then
      local argv = vim.list_slice(opts.fargs, 2)
      return core.show("pdf", argv, "dots-pdf " .. table.concat(argv, " "))
    end
    M.run(sub)
  end, {
    nargs = "*",
    desc = "PDF tools (sign, annotate, redact, merge, ...)",
    complete = function(arg)
      local names = { "raw" }
      for _, a in ipairs(actions) do
        names[#names + 1] = a.id
      end
      return vim.tbl_filter(function(n)
        return n:find(arg, 1, true) == 1
      end, names)
    end,
  })

  for key, id in pairs(KEYS) do
    local desc = id == "menu" and "PDF tools menu" or (by_id[id] and by_id[id].label or id)
    vim.keymap.set("n", "<leader>p" .. key, function()
      if id == "menu" then
        M.menu()
      else
        M.run(id)
      end
    end, { desc = "PDF: " .. desc })
    if VISUAL[key] then
      vim.keymap.set("x", "<leader>p" .. key, function()
        M.run(id, core.selection())
      end, { desc = "PDF: " .. desc .. " (selection)" })
    end
  end
end

return M
