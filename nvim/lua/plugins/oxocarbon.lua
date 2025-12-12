return {
  "nyoom-engineering/oxocarbon.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    -- layout specific settings
    vim.opt.background = "dark"
    
    -- load the colorscheme
    vim.cmd("colorscheme oxocarbon")
    
    -- Enable transparency
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })     -- For non-current windows
    vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })   -- For the column with line numbers/git signs
  end,
}
