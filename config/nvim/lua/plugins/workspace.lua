return {
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session (cwd)" },
      { "<leader>qS", function() require("persistence").select() end, desc = "Pick session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't save this session" },
    },
  },

  {
    "direnv/direnv.vim",
    lazy = false,
    cond = vim.fn.executable("direnv") == 1,
    init = function()
      vim.g.direnv_silent_load = 1
    end,
  },
}
