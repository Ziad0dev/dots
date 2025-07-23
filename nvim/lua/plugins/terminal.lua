-- ⸸ Terminal Integration - Hell's Command Line ⸸

return {
  -- Terminal integration for LazyGit, LazyDocker, and general use
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      size = 20,
      open_mapping = [[<c-\>]],
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      direction = "float",
      close_on_exit = true,
      shell = vim.o.shell,
      float_opts = {
        border = "curved",
        winblend = 0,
        highlights = {
          border = "Normal",
          background = "Normal",
        },
      },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)
      
      -- Terminal keymaps
      function _G.set_terminal_keymaps()
        local opts_term = {buffer = 0}
        vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts_term)
        vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts_term)
        vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts_term)
        vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts_term)
        vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts_term)
        vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts_term)
      end

      -- if you only want these mappings for toggle term use term://*toggleterm#* instead
      vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')

      -- Custom terminal configurations
      local Terminal = require('toggleterm.terminal').Terminal
      
      -- LazyGit terminal
      local lazygit = Terminal:new({
        cmd = "lazygit",
        dir = "git_dir",
        direction = "float",
        float_opts = {
          border = "double",
        },
        -- function to run on opening the terminal
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", {noremap = true, silent = true})
        end,
        -- function to run on closing the terminal
        on_close = function(term)
          vim.cmd("startinsert!")
        end,
      })

      function _LAZYGIT_TOGGLE()
        lazygit:toggle()
      end

      -- LazyDocker terminal
      local lazydocker = Terminal:new({
        cmd = "lazydocker",
        direction = "float",
        float_opts = {
          border = "double",
        },
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", {noremap = true, silent = true})
        end,
        on_close = function(term)
          vim.cmd("startinsert!")
        end,
      })

      function _LAZYDOCKER_TOGGLE()
        lazydocker:toggle()
      end

      -- Node.js REPL
      local node = Terminal:new({ cmd = "node", hidden = true })

      function _NODE_TOGGLE()
        node:toggle()
      end

      -- Python REPL
      local python = Terminal:new({ cmd = "python", hidden = true })

      function _PYTHON_TOGGLE()
        python:toggle()
      end

      -- Htop
      local htop = Terminal:new({ cmd = "htop", hidden = true })

      function _HTOP_TOGGLE()
        htop:toggle()
      end
    end,
    keys = {
      { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", desc = "Terminal Float" },
      { "<leader>th", "<cmd>ToggleTerm size=10 direction=horizontal<cr>", desc = "Terminal Horizontal" },
      { "<leader>tv", "<cmd>ToggleTerm size=80 direction=vertical<cr>", desc = "Terminal Vertical" },
      { "<leader>tn", "<cmd>lua _NODE_TOGGLE()<cr>", desc = "Node.js Terminal" },
      { "<leader>tp", "<cmd>lua _PYTHON_TOGGLE()<cr>", desc = "Python Terminal" },
      { "<leader>tt", "<cmd>lua _HTOP_TOGGLE()<cr>", desc = "Htop Terminal" },
      { "<c-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
    },
  },
} 