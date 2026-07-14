-- ============================================================================
-- UI EXTRAS — distraction-free writing + symbol outline
--   zen-mode + twilight (Goyo replacement) · aerial (Vista replacement)
-- ============================================================================

return {
  -- Distraction-free writing (Goyo)
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    dependencies = { "folke/twilight.nvim" },
    keys = {
      { "<leader>tz", "<cmd>ZenMode<cr>", desc = "Zen mode" },
    },
    opts = {
      window = { width = 90, options = { number = false, relativenumber = false } },
      plugins = {
        twilight = { enabled = true },
        gitsigns = { enabled = false },
      },
    },
  },

  -- Symbol / tag outline (Vista)
  {
    "stevearc/aerial.nvim",
    cmd = { "AerialToggle", "AerialOpen" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>o", "<cmd>AerialToggle<cr>", desc = "Outline (aerial)" },
    },
    opts = {
      backends = { "lsp", "treesitter", "markdown" },
      layout = { default_direction = "right", width = 30 },
      show_guides = true,
    },
  },
}
