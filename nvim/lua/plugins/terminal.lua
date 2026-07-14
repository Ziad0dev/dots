-- ============================================================================
-- TERMINAL — toggleterm
-- ============================================================================

return {
  {
    "akinsho/toggleterm.nvim",
    cmd = { "ToggleTerm", "TermExec" },
    keys = {
      { "<leader>tt", "<cmd>ToggleTerm direction=float<cr>", desc = "Terminal (float)" },
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Terminal (horizontal)" },
      { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
    },
    opts = {
      open_mapping = [[<c-\>]],
      direction = "float",
      float_opts = { border = "curved" },
      shade_terminals = false,
    },
  },
}
