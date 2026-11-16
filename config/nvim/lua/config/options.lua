vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

if vim.env.NVIM_LUA_PATH then
  package.path = package.path .. ";" .. vim.env.NVIM_LUA_PATH
end

if vim.env.NVIM_LUA_CPATH then
  package.cpath = package.cpath .. ";" .. vim.env.NVIM_LUA_CPATH
end

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.showmode = false
opt.clipboard = vim.env.SSH_CONNECTION and "" or "unnamedplus"
opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 300
opt.splitright = true
opt.splitbelow = true
opt.splitkeep = "screen"
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
opt.fillchars = { eob = " " }
opt.pumheight = 12
opt.confirm = true
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "folds" }
opt.jumpoptions = "view"
opt.completeopt = "menu,menuone,noselect"
opt.virtualedit = "block"
opt.smoothscroll = true

vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
