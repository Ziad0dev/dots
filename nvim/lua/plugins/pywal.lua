-- ⸸ HAIL SATAN - Pywal Integration ⸸

return {
  -- Pywal colorscheme integration
  {
    "dylanaraps/wal.vim",
    lazy = false,
    priority = 1000,
    config = function()
      -- Set pywal as the colorscheme
      vim.cmd("colorscheme wal")
      
      -- Occult enhancements to pywal colors
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "wal",
        callback = function()
          -- Custom occult highlighting
          vim.api.nvim_set_hl(0, "OccultSymbol", { fg = "#8B0000", bold = true })
          vim.api.nvim_set_hl(0, "SatanicText", { fg = "#FF0000", bold = true, italic = true })
          vim.api.nvim_set_hl(0, "BloodRed", { fg = "#8B0000", bg = "#000000" })
          
          -- Enhance cursor line with dark red
          vim.api.nvim_set_hl(0, "CursorLine", { bg = "#1a0000" })
          vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#FF0000", bold = true })
          
          -- Make selections more occult
          vim.api.nvim_set_hl(0, "Visual", { bg = "#4a0000" })
          
          -- Enhance search highlighting
          vim.api.nvim_set_hl(0, "Search", { fg = "#000000", bg = "#8B0000" })
          vim.api.nvim_set_hl(0, "IncSearch", { fg = "#FFFFFF", bg = "#FF0000" })
        end,
      })
    end,
  },
  
  -- Auto-reload pywal colors when they change
  {
    "AlphaTechnolog/pywal.nvim",
    name = "pywal",
    config = function()
      local pywal = require("pywal")
      pywal.setup()
    end,
  },
} 