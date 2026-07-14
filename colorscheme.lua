-- ============================================================================
-- COLORSCHEME — Oxocarbon, transparent (rice-friendly)
-- ============================================================================
-- Transparency is applied on the ColorScheme event so it survives any later
-- re-highlight (treesitter/LSP/plugin loads, cwd changes, scheme reloads).

return {
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      local accent = "#ee5396" -- oxocarbon pink

      local function make_transparent()
        local groups = {
          "Normal", "NormalNC", "NormalFloat", "FloatBorder",
          "SignColumn", "StatusLine", "StatusLineNC",
          "TelescopeNormal", "TelescopeBorder", "TelescopePromptNormal",
          "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeEndOfBuffer",
          "WhichKeyFloat", "Pmenu", "PmenuSbar",
          "LineNr", "CursorLineNr", "EndOfBuffer",
          "TabLine", "TabLineFill",
          "AerialNormal",
        }
        for _, g in ipairs(groups) do
          vim.api.nvim_set_hl(0, g, { bg = "NONE", ctermbg = "NONE" })
        end
        vim.api.nvim_set_hl(0, "FloatBorder", { bg = "NONE", fg = accent })
        vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "NONE", fg = accent, bold = true })
      end

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("oxocarbon_transparency", { clear = true }),
        pattern = "oxocarbon",
        callback = make_transparent,
      })

      vim.opt.background = "dark"
      vim.cmd.colorscheme("oxocarbon") -- fires the autocmd above
    end,
  },
}
