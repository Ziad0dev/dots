local groups = {
  "LineNr",
  "LineNrAbove",
  "LineNrBelow",
  "CursorLineNr",
  "SignColumn",
  "FoldColumn",
  "GitSignsAdd",
  "GitSignsChange",
  "GitSignsDelete",
  "DiagnosticSignError",
  "DiagnosticSignWarn",
  "DiagnosticSignInfo",
  "DiagnosticSignHint",
}

local function clear()
  for _, g in ipairs(groups) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = g, link = false })
    if ok then
      hl.bg = nil
      hl.ctermbg = nil
      pcall(vim.api.nvim_set_hl, 0, g, hl)
    end
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("GutterTransparent", { clear = true }),
  callback = clear,
})

clear()

return { clear = clear }
