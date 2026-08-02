-- ============================================================================
-- OPTIONS
-- ============================================================================

-- Leader must be set before lazy / any plugin loads.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.showmode = false             -- lualine shows the mode
opt.clipboard = "unnamedplus"
opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 300
opt.splitright = true
opt.splitbelow = true
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.inccommand = "split"
opt.cursorline = true
opt.scrolloff = 10
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.termguicolors = true
opt.wrap = false
opt.fillchars = { eob = " " }    -- hide ~ on empty lines (cleaner rice)
opt.pumheight = 12               -- cap completion menu height
opt.confirm = true               -- ask instead of failing on :q with changes

-- Disable some providers we don't use (faster startup, fewer healthcheck noises).
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
