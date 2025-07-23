-- ⸸ Editing Enhancements - Demonic Powers ⸸

return {
  -- Surround text objects (modern vim-surround)
  {
    "kylechui/nvim-surround",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        -- Configuration here, or leave empty to use defaults
      })
    end
  },

  -- Auto pairs (modern auto-pairs)
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({
        check_ts = true,
        ts_config = {
          lua = {'string'},-- it will not add a pair on that treesitter node
          javascript = {'template_string'},
          java = false,-- don't check treesitter on java
        }
      })
      
      -- Integration with cmp
      local cmp_autopairs = require('nvim-autopairs.completion.cmp')
      local cmp = require('cmp')
      cmp.event:on(
        'confirm_done',
        cmp_autopairs.on_confirm_done()
      )
    end,
  },

  -- Multiple cursors (modern vim-multiple-cursors)
  {
    "mg979/vim-visual-multi",
    branch = "master",
    init = function()
      vim.g.VM_maps = {
        ["Find Under"] = "<C-d>",
        ["Find Subword Under"] = "<C-d>",
      }
    end,
    keys = {
      { "<C-d>", desc = "Multi Cursor" },
    },
  },

  -- Comments (modern NERD commenter)
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    config = function()
      -- import comment plugin safely
      local comment = require("Comment")

      local ts_context_commentstring = require("ts_context_commentstring.integrations.comment_nvim")

      -- enable comment
      comment.setup({
        -- for commenting tsx, jsx, svelte, html files
        pre_hook = ts_context_commentstring.create_pre_hook(),
        toggler = {
          line = "<leader>nc", -- line comment toggle
          block = "<leader>ns", -- block comment toggle
        },
        opleader = {
          line = "<leader>nc", -- line comment
          block = "<leader>ns", -- block comment
        },
        extra = {
          above = "<leader>nO", -- comment line above
          below = "<leader>no", -- comment line below
          eol = "<leader>na", -- comment at end of line
        },
      })
    end,
  },

  -- Easy motion (modern vim-easymotion)
  {
    "phaazon/hop.nvim",
    branch = "v2", -- optional but strongly recommended
    config = function()
      -- you can configure Hop the way you like here; see :h hop-config
      require("hop").setup({ keys = "etovxqpdygfblzhckisuran" })
    end,
    keys = {
      { "<leader><leader>w", "<cmd>HopWord<cr>", desc = "Hop Word" },
      { "<leader><leader>e", "<cmd>HopWordMW<cr>", desc = "Hop Word Multi Window" },
      { "<leader><leader>f", "<cmd>HopChar1<cr>", desc = "Hop Char" },
      { "<leader><leader>s", "<cmd>HopChar2<cr>", desc = "Hop 2 Chars" },
      { "<leader><leader>l", "<cmd>HopLine<cr>", desc = "Hop Line" },
    },
  },

  -- Better text objects
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
    opts = function()
      local ai = require("mini.ai")
      return {
        n_lines = 500,
        custom_textobjects = {
          o = ai.gen_spec.treesitter({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }, {}),
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }, {}),
          t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
        },
      }
    end,
    config = function(_, opts)
      require("mini.ai").setup(opts)
    end,
  },

  -- Smooth scrolling (modern comfortable-motion.vim)
  {
    "karb94/neoscroll.nvim",
    config = function()
      require("neoscroll").setup({
        mappings = {"<C-u>", "<C-d>", "<C-b>", "<C-f>", "<C-y>", "<C-e>", "zt", "zz", "zb"},
        hide_cursor = true,
        stop_eof = true,
        respect_scrolloff = false,
        cursor_scrolls_alone = true,
        easing_function = nil,
        pre_hook = nil,
        post_hook = nil,
        performance_mode = false,
      })
    end,
    keys = {
      { "<C-u>", desc = "Scroll Up" },
      { "<C-d>", desc = "Scroll Down" },
    },
  },

  -- Table mode (vim-table-mode equivalent)
  {
    "dhruvasagar/vim-table-mode",
    ft = { "markdown", "text", "org" },
    keys = {
      { "<leader>tm", "<cmd>TableModeToggle<cr>", desc = "Toggle Table Mode" },
      { "<leader>tt", "<cmd>Tableize<cr>", desc = "Convert to Table", mode = "v" },
    },
  },

  -- Alignment (tabular equivalent)
  {
    "echasnovski/mini.align",
    event = "VeryLazy",
    config = function()
      require("mini.align").setup()
    end,
    keys = {
      { "ga", desc = "Align", mode = {"n", "v"} },
      { "gA", desc = "Align with preview", mode = {"n", "v"} },
    },
  },

  -- Better increment/decrement
  {
    "monaqa/dial.nvim",
    keys = {
      { "<C-a>", function() require("dial.map").manipulate("increment", "normal") end, desc = "Increment" },
      { "<C-x>", function() require("dial.map").manipulate("decrement", "normal") end, desc = "Decrement" },
      { "g<C-a>", function() require("dial.map").manipulate("increment", "gnormal") end, desc = "Increment" },
      { "g<C-x>", function() require("dial.map").manipulate("decrement", "gnormal") end, desc = "Decrement" },
      { "<C-a>", function() require("dial.map").manipulate("increment", "visual") end, mode = "v", desc = "Increment" },
      { "<C-x>", function() require("dial.map").manipulate("decrement", "visual") end, mode = "v", desc = "Decrement" },
      { "g<C-a>", function() require("dial.map").manipulate("increment", "gvisual") end, mode = "v", desc = "Increment" },
      { "g<C-x>", function() require("dial.map").manipulate("decrement", "gvisual") end, mode = "v", desc = "Decrement" },
    },
  },
} 