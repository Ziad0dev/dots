-- ============================================================================
-- EDITING ENHANCEMENTS
--   surround · comment · indent guides · motion (flash) · smooth scroll · which-key
-- ============================================================================

return {
  -- Surround (vim-surround)
  { "kylechui/nvim-surround", event = "VeryLazy", opts = {} },

  -- Comments (NERDcommenter)
  {
    "numToStr/Comment.nvim",
    keys = {
      { "gcc", mode = "n", desc = "Comment line" },
      { "gc", mode = { "n", "v" }, desc = "Comment" },
    },
    opts = {},
  },

  -- Indent guides (indentLine)
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    main = "ibl",
    config = function()
      local hooks = require("ibl.hooks")
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, "IblIndent", { fg = "#3c3c3c" })
        vim.api.nvim_set_hl(0, "IblScope", { fg = "#ee5396" })
      end)
      require("ibl").setup({
        indent = { char = "│", highlight = "IblIndent" },
        scope = { enabled = true, highlight = "IblScope" },
      })
    end,
  },

  -- Motion (easymotion replacement)
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    },
  },

  -- Smooth scrolling (comfortable-motion replacement)
  {
    "karb94/neoscroll.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- Keybinding hints
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
      },
    },
  },
}
