local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable", repo, lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to bootstrap lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }, true, {})
    return
  end
end
vim.opt.rtp:prepend(lazypath)

-- The config is a read-only store copy unless dots.liveConfig is on, so the
-- lockfile lives in state instead. The repo's lazy-lock.json seeds it on first
-- start, so a fresh install gets the pinned versions; copy it back into the
-- repo to record updates.
local lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json"
local seed = vim.fn.stdpath("config") .. "/lazy-lock.json"
if not (vim.uv or vim.loop).fs_stat(lockfile) and (vim.uv or vim.loop).fs_stat(seed) then
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  vim.fn.writefile(vim.fn.readfile(seed, "b"), lockfile, "b")
end

require("lazy").setup({
  lockfile = lockfile,
  spec = {
    { import = "plugins" },
  },
  rocks = { enabled = false },
  install = { colorscheme = { "dots", "habamax" } },
  checker = { enabled = true, notify = false, frequency = 604800 },
  change_detection = { notify = false },
  ui = { border = "rounded" },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
        "netrwPlugin", "rplugin", "spellfile", "matchit",
      },
    },
  },
})

vim.keymap.set("n", "<leader>L", "<cmd>Lazy<cr>", { desc = "Lazy" })
