return {
  {
    "nvim-mini/mini.base16",
    lazy = false,
    priority = 1000,
    config = function()
      require("config.theme").setup()
      vim.cmd.colorscheme("dots")
    end,
  },
}
