return {
  {
    "nvim-mini/mini.base16",
    lazy = false,
    priority = 1100,
    config = function()
      require("config.theme").setup()
      vim.cmd.colorscheme("dots")
    end,
  },
}
