-- ⸸ HAIL SATAN - Simple & Complete Neovim Config ⸸

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ============================================================================
-- OPTIONS
-- ============================================================================
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.showmode = false
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

-- ============================================================================
-- KEYMAPS
-- ============================================================================
local map = vim.keymap.set

-- Better window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Resize windows
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ": m '>+1<cr>gv=gv", { desc = "Move lines down" })
map("v", "<A-k>", ": m '<-2<cr>gv=gv", { desc = "Move lines up" })

-- Better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Clear search
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Save & Quit
map("n", "<C-s>", "<cmd>w<cr>", { desc = "Save file" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

-- Diagnostic keymaps
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show diagnostic error" })

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Restore cursor position
autocmd("BufReadPost", {
  group = augroup("restore_cursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close some filetypes with <q>
autocmd("FileType", {
  group = augroup("close_with_q", { clear = true }),
  pattern = { "help", "lspinfo", "qf", "checkhealth", "notify" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    map("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- LSP Keymaps on attach
autocmd("LspAttach", {
  group = augroup("lsp_attach", { clear = true }),
  callback = function(event)
    local opts = { buffer = event.buf }
    map("n", "gd", vim.lsp.buf.definition, opts)
    map("n", "gD", vim.lsp.buf.declaration, opts)
    map("n", "gi", vim. lsp.buf.implementation, opts)
    map("n", "gr", vim.lsp.buf. references, opts)
    map("n", "K", vim.lsp.buf. hover, opts)
    map("n", "<leader>rn", vim.lsp.buf.rename, opts)
    map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    map("n", "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, opts)
  end,
})

-- ============================================================================
-- LAZY. NVIM BOOTSTRAP
-- ============================================================================
local lazypath = vim.fn. stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob: none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================================
-- PLUGINS
-- ============================================================================
require("lazy").setup({
  -- Colorscheme:  Oxocarbon with transparency
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.background = "dark"
      vim. cmd.colorscheme("oxocarbon")

      -- Enable transparency
      local groups = {
        "Normal", "NormalNC", "NormalFloat", "FloatBorder",
        "SignColumn", "StatusLine", "StatusLineNC",
        "TelescopeNormal", "TelescopeBorder", "TelescopePromptNormal",
        "NeoTreeNormal", "NeoTreeNormalNC",
        "WhichKeyFloat", "Pmenu", "PmenuSbar",
        "LineNr", "CursorLineNr", "EndOfBuffer",
        "TabLine", "TabLineFill",
      }
      for _, group in ipairs(groups) do
        vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
      end

      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "FloatBorder", { bg = "NONE", fg = "#ee5396" })
    end,
  },

  -- File explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "File Explorer" },
    },
    opts = {
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = { hide_dotfiles = false },
      },
    },
  },

  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Search in buffer" },
      { "<leader><leader>", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          mappings = {
            i = {
              ["<C-j>"] = "move_selection_next",
              ["<C-k>"] = "move_selection_previous",
            },
          },
        },
      })
      pcall(require("telescope").load_extension, "fzf")
    end,
  },

  -- Treesitter (syntax highlighting)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter.config").setup({
        ensure_installed = {
          "bash", "c", "cpp", "css", "go", "html", "javascript", "json",
          "lua", "markdown", "markdown_inline", "python", "rust", "tsx",
          "typescript", "vim", "vimdoc", "yaml", "latex", "bibtex",
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- Mason (LSP/tool installer)
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    opts = {},
  },

  -- Mason-lspconfig bridge
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = { "lua_ls", "pyright", "ts_ls", "rust_analyzer" },
      automatic_installation = true,
    },
  },

  -- LSP Configuration (Neovim 0.11+ native API)
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      vim.diagnostic.config({
        virtual_text = { prefix = "●" },
        signs = true,
        update_in_insert = false,
        float = { border = "rounded" },
      })

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      if ok then
        capabilities = cmp_lsp.default_capabilities(capabilities)
      end

      vim.lsp.config("lua_ls", {
        cmd = { "lua-language-server" },
        filetypes = { "lua" },
        root_markers = { ".luarc.json", ".stylua.toml", ".git" },
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.config("pyright", {
        cmd = { "pyright-langserver", "--stdio" },
        filetypes = { "python" },
        root_markers = { "pyproject.toml", "setup.py", "requirements.txt", ".git" },
        capabilities = capabilities,
      })

      vim.lsp.config("ts_ls", {
        cmd = { "typescript-language-server", "--stdio" },
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
        root_markers = { "tsconfig.json", "jsconfig. json", "package.json", ".git" },
        capabilities = capabilities,
      })

      vim.lsp.config("rust_analyzer", {
        cmd = { "rust-analyzer" },
        filetypes = { "rust" },
        root_markers = { "Cargo.toml", ".git" },
        capabilities = capabilities,
      })

      vim.lsp.config("clangd", {
        cmd = { "clangd" },
        filetypes = { "c", "cpp", "objc", "objcpp" },
        root_markers = { "compile_commands.json", ".git" },
        capabilities = capabilities,
      })

      vim.lsp.config("gopls", {
        cmd = { "gopls" },
        filetypes = { "go", "gomod", "gowork", "gotmpl" },
        root_markers = { "go.mod", ".git" },
        capabilities = capabilities,
      })

      vim.lsp.enable({ "lua_ls", "pyright", "ts_ls", "rust_analyzer", "clangd", "gopls" })
    end,
  },

  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset. insert({
          ["<C-b>"] = cmp.mapping. scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping. complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping. confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },

  -- Autopairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup()
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },

  -- Git signs
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
      },
      on_attach = function(bufnr)
        local gs = package. loaded.gitsigns
        local opts = { buffer = bufnr }
        map("n", "]h", gs.next_hunk, opts)
        map("n", "[h", gs.prev_hunk, opts)
        map("n", "<leader>hs", gs.stage_hunk, opts)
        map("n", "<leader>hr", gs.reset_hunk, opts)
        map("n", "<leader>hp", gs.preview_hunk, opts)
        map("n", "<leader>hb", gs.blame_line, opts)
      end,
    },
  },

  -- Which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>h", group = "git hunks" },
        { "<leader>c", group = "code" },
        { "<leader>b", group = "buffer" },
        { "<leader>q", group = "quit" },
        { "<leader>t", group = "terminal" },
        { "<leader>m", group = "markdown" },
        { "<leader>l", group = "latex" },
      },
    },
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
      },
    },
  },

  -- Bufferline
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        offsets = {
          { filetype = "neo-tree", text = "File Explorer", text_align = "center" },
        },
      },
    },
  },

  -- Indent guides (loads after colorscheme)
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nyoom-engineering/oxocarbon.nvim" },
    main = "ibl",
    config = function()
      local hooks = require("ibl.hooks")
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, "IblIndent", { fg = "#3c3c3c" })
        vim.api.nvim_set_hl(0, "IblScope", { fg = "#ee5396" })
      end)
      require("ibl").setup({
        indent = { char = "│", highlight = "IblIndent" },
        scope = { enabled = true, highlight = "IblScope" },
      })
    end,
  },

  -- Comments
  {
    "numToStr/Comment.nvim",
    keys = {
      { "gcc", mode = "n", desc = "Comment line" },
      { "gc", mode = { "n", "v" }, desc = "Comment" },
    },
    opts = {},
  },

  -- Surround
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    opts = {},
  },

  -- Terminal
  {
    "akinsho/toggleterm.nvim",
    keys = {
      { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
      { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", desc = "Float terminal" },
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Horizontal terminal" },
      { "<leader>tv", "<cmd>ToggleTerm direction=vertical size=80<cr>", desc = "Vertical terminal" },
    },
    opts = {
      open_mapping = [[<C-\>]],
      direction = "float",
      float_opts = { border = "rounded" },
    },
  },

  -- Lazygit
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
    },
  },

  -- ============================================================================
  -- MARKDOWN & LATEX SUPPORT
  -- ============================================================================

  -- Markdown Preview (opens in browser)
  -- 
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = "cd app && npm install",  -- Use npm directly instead of vim function
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
      { "<leader>ms", "<cmd>MarkdownPreviewStop<cr>", desc = "Markdown Preview Stop" },
    },
    init = function()
      vim.g.mkdp_auto_close = 0
      vim.g. mkdp_theme = "dark"
      vim.g.mkdp_browser = ""
      vim.g.mkdp_preview_options = {
        mkit = {},
        katex = {},
        uml = {},
        maid = {},
        disable_sync_scroll = 0,
        sync_scroll_type = "middle",
      }
    end,
  },
  -- Better Markdown rendering in buffer
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      heading = {
        enabled = true,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      code = {
        enabled = true,
        style = "full",
      },
      bullet = {
        enabled = true,
        icons = { "●", "○", "◆", "◇" },
      },
    },
  },

  -- LaTeX support with VimTeX
  {
    "lervag/vimtex",
    ft = { "tex", "latex", "bib" },
    init = function()
      -- PDF viewer - change to your preferred viewer: 
      -- Linux: "zathura", "evince", "okular", "sioyek"
      -- macOS: "skim", "sioyek", "preview"
      -- Windows: "sumatrapdf", "sioyek"
      vim.g.vimtex_view_method = "zathura"

      -- Compiler settings
      vim.g.vimtex_compiler_method = "latexmk"
      vim.g.vimtex_compiler_latexmk = {
        build_dir = "",
        callback = 1,
        continuous = 1,
        executable = "latexmk",
        options = {
          "-verbose",
          "-file-line-error",
          "-synctex=1",
          "-interaction=nonstopmode",
        },
      }

      -- Don't open quickfix for warnings
      vim.g.vimtex_quickfix_mode = 0

      -- Set tex flavor
      vim.g.tex_flavor = "latex"

      -- Concealment settings (hide LaTeX markup)
      vim.g.vimtex_syntax_conceal = {
        accents = 1,
        cites = 1,
        fancy = 1,
        greek = 1,
        math_bounds = 1,
        math_delimiters = 1,
        math_fracs = 1,
        math_super_sub = 1,
        math_symbols = 1,
        sections = 0,
        styles = 1,
      }

      -- TOC settings
      vim.g. vimtex_toc_config = {
        name = "TOC",
        layers = { "content", "todo", "include" },
        split_width = 25,
        todo_sorted = 0,
        show_help = 1,
        show_numbers = 1,
      }
    end,
    keys = {
      { "<leader>ll", "<cmd>VimtexCompile<cr>", desc = "LaTeX Compile" },
      { "<leader>lv", "<cmd>VimtexView<cr>", desc = "LaTeX View PDF" },
      { "<leader>lt", "<cmd>VimtexTocToggle<cr>", desc = "LaTeX TOC" },
      { "<leader>lc", "<cmd>VimtexClean<cr>", desc = "LaTeX Clean" },
      { "<leader>le", "<cmd>VimtexErrors<cr>", desc = "LaTeX Errors" },
      { "<leader>ls", "<cmd>VimtexStop<cr>", desc = "LaTeX Stop" },
      { "<leader>li", "<cmd>VimtexInfo<cr>", desc = "LaTeX Info" },
    },
  },

  -- LaTeX snippets for faster writing
  {
    "evesdropper/luasnip-latex-snippets.nvim",
    ft = { "tex", "latex" },
    dependencies = { "L3MON4D3/LuaSnip" },
    config = function()
      require("luasnip-latex-snippets").setup()
    end,
  },

}, {
  install = { colorscheme = { "oxocarbon" } },
  checker = { enabled = true, notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin", "netrwPlugin",
      },
    },
  },
})
