
return {

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
