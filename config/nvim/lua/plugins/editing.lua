return {

  { "kylechui/nvim-surround", event = "VeryLazy", opts = {} },

  {
    "folke/ts-comments.nvim",
    event = "VeryLazy",
    opts = {},
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>h", group = "git hunks" },
        { "<leader>g", group = "git" },
        { "<leader>c", group = "code" },
        { "<leader>b", group = "buffer" },
        { "<leader>q", group = "quit" },
        { "<leader>t", group = "terminal/toggle" },
        { "<leader>m", group = "markdown" },
        { "<leader>r", group = "rename/refactor" },
        { "<leader>d", group = "document (tex/typst)" },
        { "<leader>u", group = "ui" },
        { "<leader>y", group = "yazi" },
      },
    },
  },
}
