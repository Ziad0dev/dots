local M = {}

local state = vim.fs.joinpath(
  vim.env.XDG_STATE_HOME or vim.fs.joinpath(vim.env.HOME, ".local", "state"),
  "dots",
  "theme"
)

M.file = vim.fs.joinpath(state, "nvim.lua")

M.fallback = {
  base00 = "#161616", base01 = "#262626", base02 = "#393939", base03 = "#525252",
  base04 = "#dde1e6", base05 = "#f2f4f8", base06 = "#ffffff", base07 = "#08bdba",
  base08 = "#3ddbd9", base09 = "#78a9ff", base0A = "#ee5396", base0B = "#33b1ff",
  base0C = "#ff7eb6", base0D = "#42be65", base0E = "#be95ff", base0F = "#82cfff",
  bg = "#161616", fg = "#f2f4f8", cursor = "#f2f4f8", accent = "#ee5396",
  sel_bg = "#ee5396", sel_fg = "#f2f4f8",
  dim = "#5f6266", muted = "#9ba0a5", surface = "#232323",
  red = "#ee5396", green = "#42be65", yellow = "#ffe97b",
  blue = "#33b1ff", magenta = "#be95ff", cyan = "#3ddbd9", pink = "#ff7eb6",
}

local function rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function mix(a, b, w)
  local ar, ag, ab = rgb(a)
  local br, bg, bb = rgb(b)
  return string.format(
    "#%02x%02x%02x",
    math.floor((ar * (100 - w) + br * w) / 100),
    math.floor((ag * (100 - w) + bg * w) / 100),
    math.floor((ab * (100 - w) + bb * w) / 100)
  )
end

local function lum(hex)
  local r, g, b = rgb(hex)
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255
end

local function light(hex)
  return lum(hex) > 0.5
end

local function bgside(c, bg, fg, w)
  if math.abs(lum(c) - lum(bg)) > math.abs(lum(c) - lum(fg)) then
    return mix(bg, fg, w)
  end
  return c
end

local function repair(p)
  local q = vim.tbl_extend("force", {}, p)
  q.surface = q.surface or mix(q.base00, q.base05, 8)
  q.dim = q.dim or mix(q.base05, q.base00, 35)
  q.muted = q.muted or mix(q.base05, q.base00, 60)
  q.base01 = bgside(q.base01, q.base00, q.base05, 8)
  q.base02 = bgside(q.base02, q.base00, q.base05, 18)
  if q.base01 == q.base00 then q.base01 = q.surface end
  if q.base02 == q.base01 then q.base02 = mix(q.base00, q.base05, 18) end
  if q.base03 == q.base02 or q.base03 == q.base04 or q.base03 == q.base05 then
    q.base03 = q.muted
  end
  if q.base04 == q.base05 then q.base04 = q.dim end
  return q
end

function M.load()
  local ok, p = pcall(dofile, M.file)
  if not ok or type(p) ~= "table" or type(p.base00) ~= "string" then
    return repair(M.fallback)
  end
  return repair(vim.tbl_extend("keep", p, M.fallback))
end

function M.name()
  local f = io.open(vim.fs.joinpath(state, "current"), "r")
  if not f then return "fallback" end
  local n = f:read("l")
  f:close()
  return n or "fallback"
end

local function read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local body = f:read("a")
  f:close()
  if body == nil or body == "" then return nil end
  return body
end

function M.art(default)
  local dir = vim.fn.stdpath("config") .. "/art"
  return read(dir .. "/themes/" .. M.name() .. ".txt")
    or read(dir .. "/" .. (default or "nixos") .. ".txt")
    or ""
end

local function untint(group)
  local ok, cur = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  if not ok or vim.tbl_isempty(cur) then return end
  cur.bg, cur.ctermbg = nil, nil
  pcall(vim.api.nvim_set_hl, 0, group, cur)
end

local transparent_groups = {
  "Normal", "NormalNC", "NormalFloat", "FloatBorder", "FloatTitle",
  "SignColumn", "FoldColumn", "LineNr", "CursorLineNr", "EndOfBuffer",
  "StatusLine", "StatusLineNC", "WinBar", "WinBarNC", "MsgArea",
  "TabLine", "TabLineFill", "Pmenu", "PmenuSbar",
  "SnacksNormal", "SnacksNormalNC", "SnacksWinBar",
  "SnacksPickerNormal", "SnacksPickerBorder", "SnacksPickerTitle",
  "SnacksPickerPreview", "SnacksPickerPreviewBorder", "SnacksPickerList",
  "SnacksPickerInput", "SnacksPickerInputBorder", "SnacksPickerTree",
  "SnacksDashboardNormal", "SnacksDashboardHeader",
  "SnacksIndent", "SnacksIndentScope",
  "OilNormal", "AerialNormal", "WhichKeyFloat", "WhichKeyNormal",
  "TelescopeNormal", "TelescopeBorder", "TelescopePromptNormal",
}

function M.highlights(p)
  if vim.g.dots_transparent ~= false then
    for _, g in ipairs(transparent_groups) do
      untint(g)
    end
  end

  local set = function(g, o) vim.api.nvim_set_hl(0, g, o) end

  set("FloatBorder", { fg = p.accent, bg = "NONE" })
  set("FloatTitle", { fg = p.accent, bg = "NONE", bold = true })
  set("CursorLineNr", { fg = p.accent, bg = "NONE", bold = true })
  set("CursorLine", { bg = p.surface })
  set("ColorColumn", { bg = p.surface })
  set("Visual", { bg = mix(p.base00, p.accent, 22) })
  set("MatchParen", { fg = p.accent, bold = true })
  set("Cursor", { fg = p.base00, bg = p.cursor })

  set("SnacksPickerMatch", { fg = p.accent, bold = true })
  set("SnacksPickerDir", { fg = p.muted })
  set("SnacksPickerCursorLine", { bg = p.surface })
  set("SnacksDashboardKey", { fg = p.accent, bold = true })
  set("SnacksDashboardDesc", { fg = p.base05 })
  set("SnacksDashboardHeader", { fg = p.accent })
  set("SnacksDashboardFooter", { fg = p.muted })
  set("SnacksIndent", { fg = p.base02 })
  set("SnacksIndentScope", { fg = p.accent })

  set("DiagnosticError", { fg = p.red })
  set("DiagnosticWarn", { fg = p.yellow })
  set("DiagnosticInfo", { fg = p.blue })
  set("DiagnosticHint", { fg = p.cyan })

  vim.api.nvim_exec_autocmds("User", { pattern = "DotsThemeApplied", modeline = false })
end

function M.apply()
  local p = M.load()
  vim.o.background = light(p.base00) and "light" or "dark"

  local ok, base16 = pcall(require, "mini.base16")
  if ok then
    base16.setup({
      palette = {
        base00 = p.base00, base01 = p.base01, base02 = p.base02, base03 = p.base03,
        base04 = p.base04, base05 = p.base05, base06 = p.base06, base07 = p.base07,
        base08 = p.base08, base09 = p.base09, base0A = p.base0A, base0B = p.base0B,
        base0C = p.base0C, base0D = p.base0D, base0E = p.base0E, base0F = p.base0F,
      },
      use_cterm = false,
    })
  end

  M.highlights(p)
  M.palette = p
end

function M.reload()
  vim.cmd.colorscheme("dots")
end

function M.watch()
  if M.handle or vim.fn.isdirectory(state) == 0 then return end
  local handle = (vim.uv or vim.loop).new_fs_event()
  if not handle then return end
  local pending = false
  handle:start(state, {}, function(err, fname)
    if err or fname ~= "nvim.lua" or pending then return end
    pending = true
    vim.defer_fn(function()
      pending = false
      pcall(M.reload)
    end, 120)
  end)
  M.handle = handle
end

function M.setup()
  vim.api.nvim_create_user_command("DotsThemeReload", M.reload, { desc = "Re-read the themectl palette" })
  vim.api.nvim_create_user_command("DotsThemeToggleTransparency", function()
    vim.g.dots_transparent = vim.g.dots_transparent == false
    M.reload()
  end, { desc = "Toggle background transparency" })
  M.watch()
end

return M
