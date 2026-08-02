-- ============================================================================
-- MARKDOWN — preview + table mode
-- ============================================================================

return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    ft = "markdown",
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_theme = "dark"
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown preview", ft = "markdown" },
    },
  },

  {
    "dhruvasagar/vim-table-mode",
    cmd = { "TableModeToggle", "TableModeRealign" },
    keys = {
      { "<leader>mt", "<cmd>TableModeToggle<cr>", desc = "Table mode toggle" },
    },
  },
}
