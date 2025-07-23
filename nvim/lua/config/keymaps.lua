-- ⸸ Keymaps - Hellish Bindings ⸸

-- Set space as leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = vim.keymap

-- ⸸ BASIC KEYBINDS ⸸
-- Exit insert mode with jk or kj (vim.reaper style)
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })
keymap.set("i", "kj", "<ESC>", { desc = "Exit insert mode with kj" })

-- Clear search highlights
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- Delete single character without copying into register
keymap.set("n", "x", '"_x')

-- Increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" })
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" })

-- ⸸ NAVIGATION ⸸ (vim.reaper style)
-- Window management
keymap.set("n", "<C-h>", "<C-w>h", { desc = "Navigate to left window" })
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Navigate to bottom window" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Navigate to top window" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Navigate to right window" })

-- Window splits (vim.reaper style)
keymap.set("n", "<leader><C-s>", "<C-w>s<C-w>j", { desc = "Horizontal split then move to bottom window" })
keymap.set("n", "<leader><C-l>", "<C-w>v<C-w>l", { desc = "Vertical split then move to right window" })

-- Resize window
keymap.set("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase window height" })
keymap.set("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease window height" })
keymap.set("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease window width" })
keymap.set("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase window width" })

-- ⸸ BUFFER MANAGEMENT ⸸ (vim.reaper style)
-- Buffer navigation
keymap.set("n", "<Tab>", ":bnext<CR>", { desc = "Next buffer" })
keymap.set("n", "<S-Tab>", ":bprevious<CR>", { desc = "Previous buffer" })
keymap.set("n", "<leader>bk", ":bdelete<CR>", { desc = "Kill buffer" })
keymap.set("n", "<leader>bn", ":enew<CR>", { desc = "New buffer" })

-- ⸸ FILE EXPLORER ⸸
-- Neo-tree (modern NERDTree)
keymap.set("n", "<F7>", ":Neotree toggle<CR>", { desc = "Toggle file explorer" })

-- ⸸ GIT ⸸ (vim.reaper style but modernized)
-- LazyGit (vim.reaper had this)
keymap.set("n", "<leader>lg", ":LazyGit<CR>", { desc = "LazyGit" })
keymap.set("n", "<leader>gg", ":LazyGit<CR>", { desc = "LazyGit" })

-- Git hunks (gitsigns)
keymap.set("n", "]h", ":Gitsigns next_hunk<CR>", { desc = "Next git hunk" })
keymap.set("n", "[h", ":Gitsigns prev_hunk<CR>", { desc = "Previous git hunk" })
keymap.set("n", "<leader>ghs", ":Gitsigns stage_hunk<CR>", { desc = "Stage hunk" })
keymap.set("n", "<leader>ghr", ":Gitsigns reset_hunk<CR>", { desc = "Reset hunk" })
keymap.set("n", "<leader>ghp", ":Gitsigns preview_hunk<CR>", { desc = "Preview hunk" })
keymap.set("n", "<leader>gb", ":GitBlameToggle<CR>", { desc = "Toggle git blame" })

-- ⸸ DOCKER ⸸ (vim.reaper style)
keymap.set("n", "<leader>ld", function() require("lazydocker").toggle() end, { desc = "LazyDocker" })

-- ⸸ TELESCOPE ⸸ (modern fzf alternative)
keymap.set("n", "<leader>ff", ":Telescope find_files<CR>", { desc = "Find files" })
keymap.set("n", "<leader>fs", ":Telescope live_grep<CR>", { desc = "Find string in cwd" })
keymap.set("n", "<leader>fc", ":Telescope grep_string<CR>", { desc = "Find string under cursor in cwd" })
keymap.set("n", "<leader>fb", ":Telescope buffers<CR>", { desc = "Show open buffers" })
keymap.set("n", "<leader>fh", ":Telescope help_tags<CR>", { desc = "Find help" })
keymap.set("n", "<leader>fo", ":Telescope oldfiles<CR>", { desc = "Find recent files" })
keymap.set("n", "<leader>fz", ":Telescope current_buffer_fuzzy_find<CR>", { desc = "Find in current buffer" })

-- Git telescope
keymap.set("n", "<leader>gc", ":Telescope git_commits<CR>", { desc = "Show git commits" })
keymap.set("n", "<leader>gfc", ":Telescope git_bcommits<CR>", { desc = "Show git commits for current buffer" })
keymap.set("n", "<leader>gb", ":Telescope git_branches<CR>", { desc = "Show git branches" })
keymap.set("n", "<leader>gs", ":Telescope git_status<CR>", { desc = "Show current git changes" })

-- ⸸ LSP ⸸ (modern coc.nvim replacement)
keymap.set("n", "gR", ":Telescope lsp_references<CR>", { desc = "Show LSP references" })
keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
keymap.set("n", "gd", ":Telescope lsp_definitions<CR>", { desc = "Show LSP definitions" })
keymap.set("n", "gi", ":Telescope lsp_implementations<CR>", { desc = "Show LSP implementations" })
keymap.set("n", "gt", ":Telescope lsp_type_definitions<CR>", { desc = "Show LSP type definitions" })
keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "See available code actions" })
keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Smart rename" })
keymap.set("n", "<leader>D", ":Telescope diagnostics bufnr=0<CR>", { desc = "Show buffer diagnostics" })
keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show line diagnostics" })
keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic" })
keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })
keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Show documentation for what is under cursor" })
keymap.set("n", "<leader>rs", ":LspRestart<CR>", { desc = "Restart LSP" })

-- ⸸ FORMATTING ⸸
keymap.set({ "n", "v" }, "<leader>mp", function()
  require("conform").format({
    lsp_fallback = true,
    async = false,
    timeout_ms = 1000,
  })
end, { desc = "Format file or range (in visual mode)" })

-- ⸸ TERMINAL ⸸ (vim.reaper style)
keymap.set("n", "<C-\\>", ":ToggleTerm<CR>", { desc = "Toggle terminal" })
keymap.set("t", "<C-\\>", "<C-\\><C-n>:ToggleTerm<CR>", { desc = "Toggle terminal" })
keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- ⸸ MISC ⸸ (vim.reaper style)
-- Save and quit
keymap.set("n", "<leader>w", ":w<CR>", { desc = "Save file" })
keymap.set("n", "<leader>q", ":q<CR>", { desc = "Quit" })
keymap.set("n", "<leader>wq", ":wq<CR>", { desc = "Save and quit" })
keymap.set("n", "<leader>Q", ":q!<CR>", { desc = "Quit without saving" })

-- Select all
keymap.set("n", "<C-a>", "gg<S-v>G", { desc = "Select all" })

-- Better indenting
keymap.set("v", "<", "<gv", { desc = "Indent left" })
keymap.set("v", ">", ">gv", { desc = "Indent right" })

-- Move text up and down
keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move text down" })
keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move text up" })

-- Stay in indent mode
keymap.set("v", "<", "<gv")
keymap.set("v", ">", ">gv")

-- Keep last yanked when pasting
keymap.set("v", "p", '"_dP')

-- ⸸ PLUGIN SPECIFIC ⸸

-- Zen mode (modern Goyo)
keymap.set("n", "<leader>z", ":ZenMode<CR>", { desc = "Toggle zen mode" })

-- Trouble
keymap.set("n", "<leader>xx", ":TroubleToggle<CR>", { desc = "Open/close trouble list" })
keymap.set("n", "<leader>xw", ":TroubleToggle workspace_diagnostics<CR>", { desc = "Open trouble workspace diagnostics" })
keymap.set("n", "<leader>xd", ":TroubleToggle document_diagnostics<CR>", { desc = "Open trouble document diagnostics" })
keymap.set("n", "<leader>xq", ":TroubleToggle quickfix<CR>", { desc = "Open trouble quickfix list" })
keymap.set("n", "<leader>xl", ":TroubleToggle loclist<CR>", { desc = "Open trouble location list" })
keymap.set("n", "gR", ":TroubleToggle lsp_references<CR>", { desc = "Open trouble lsp references" })

-- Markdown preview (vim.reaper had this)
keymap.set("n", "<leader>md", ":MarkdownPreview<CR>", { desc = "Markdown preview" })

-- ⸸ PICOM TOGGLE ⸸
keymap.set("n", "<leader>pc", function()
  vim.cmd("!~/.config/polybar/picom_toggle.sh --toggle")
end, { desc = "Toggle Picom" }) 