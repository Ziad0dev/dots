-- ⸸ Core Neovim Options - Satanic Configuration ⸸

local opt = vim.opt

-- Performance
opt.updatetime = 250
opt.timeoutlen = 300

-- UI
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.termguicolors = true
opt.showmode = false
opt.cmdheight = 1
opt.pumheight = 15
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.linebreak = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Indentation  
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Files
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.undodir = vim.fn.stdpath("data") .. "/undo"

-- Completion
opt.completeopt = { "menu", "menuone", "noselect" }
opt.pumblend = 10

-- Clipboard
opt.clipboard = "unnamedplus"

-- Mouse
opt.mouse = "a"

-- Wildmenu
opt.wildmode = "longest:full,full"

-- Better diff
opt.diffopt:append("linematch:60")

-- Spell checking
opt.spelllang = "en_us"
opt.spellfile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add"

-- Disable some providers
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0

-- Dark theme preference  
vim.o.background = "dark" 