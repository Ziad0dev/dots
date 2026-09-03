return {
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
