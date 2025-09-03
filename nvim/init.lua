-- ⸸ HAIL SATAN ⸸

-- Set leader keys before loading plugins
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Apply critical LSP buffer fix before anything else
pcall(function()
  require("utils.lsp_buffer_fix")
end)

-- Bootstrap lazy.nvim (modern plugin manager)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load core configuration modules
require("core.options")
require("core.keymaps")
require("core.autocmds")

-- Apply LSP buffer fix early
pcall(function()
  require("utils.lsp_buffer_fix")
  require("utils.cmp_fix").setup()
end)

-- Setup lazy.nvim and load plugins
require("lazy").setup("plugins", {
  defaults = {
    lazy = false,
    version = false,
  },
  install = { colorscheme = { "wal", "tokyonight-night" } },
  checker = { enabled = true },
  rocks = { enabled = false }, -- Disable luarocks to avoid warnings
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

-- ⸸ Custom Satanic Notifications
local function satanic_notify(msg, level)
  local icons = {
    [vim.log.levels.ERROR] = "⸸",
    [vim.log.levels.WARN] = "⛧",
    [vim.log.levels.INFO] = "☠",
    [vim.log.levels.DEBUG] = "🕯",
  }
  local icon = icons[level] or "👹"
  local formatted_msg = string.format("%s %s", icon, msg)
  vim.api.nvim_echo({{formatted_msg, "Normal"}}, false, {})
end

-- Override vim.notify with our satanic version
vim.notify = satanic_notify

-- Satanic welcome message
vim.defer_fn(function()
  satanic_notify("HAIL SATAN", vim.log.levels.INFO)
end, 50) 
