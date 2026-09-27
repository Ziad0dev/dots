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

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = { focus = true },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Workspace diagnostics" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics" },
      { "<leader>xs", "<cmd>Trouble symbols toggle<cr>", desc = "Symbols" },
      { "<leader>xl", "<cmd>Trouble lsp toggle win.position=right<cr>", desc = "LSP defs/refs" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location list" },
    },
  },

  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next todo" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Prev todo" },
      { "<leader>xt", "<cmd>Trouble todo toggle<cr>", desc = "Todos" },
      { "<leader>ft", function() Snacks.picker.todo_comments() end, desc = "Todos" },
    },
  },
}
