-- ⸸ HAIL SATAN - AI & Copilot (LOCAL MODELS) ⸸

return {
  -- GitHub Copilot (Paid Service - Keeping)
  {
    "github/copilot.vim",
    event = "InsertEnter",
    config = function()
      -- Disable default tab mapping (we'll use custom ones)
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_assume_mapped = true
      
      -- Enable Copilot for all filetypes
      vim.g.copilot_filetypes = {
        ["*"] = true,
      }
      
      -- Custom keymaps for Copilot
      vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
        expr = true,
        replace_keycodes = false,
        desc = "Accept Copilot suggestion"
      })
      
      vim.keymap.set("i", "<C-L>", "<Plug>(copilot-accept-word)", {
        desc = "Accept Copilot word"
      })
      
      vim.keymap.set("i", "<C-H>", "<Plug>(copilot-previous)", {
        desc = "Previous Copilot suggestion"
      })
      
      vim.keymap.set("i", "<C-K>", "<Plug>(copilot-next)", {
        desc = "Next Copilot suggestion"
      })
      
      vim.keymap.set("i", "<C-\\>", "<Plug>(copilot-dismiss)", {
        desc = "Dismiss Copilot suggestion"
      })
    end,
  },

  -- Copilot Chat for AI conversations
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      "github/copilot.vim",
      "nvim-lua/plenary.nvim",
    },
    opts = {
      debug = false,
      show_help = "yes",
      prompts = {
        Explain = "Please explain how the following code works.",
        Review = "Please review the following code and provide suggestions for improvement.",
        Tests = "Please explain how the selected code works, then generate unit tests for it.",
        Refactor = "Please refactor the following code to improve its clarity and readability.",
        FixCode = "Please fix the following code to make it work as intended.",
        FixError = "Please explain the error in the following text and provide a solution.",
        BetterNamings = "Please provide better names for the following variables and functions.",
        Documentation = "Please provide documentation for the following code.",
        SwaggerApiDocs = "Please provide documentation for the following API using Swagger.",
        SwaggerJSDoc = "Please write JSDoc for the following API using Swagger.",
        Summarize = "Please summarize the following text.",
        Spelling = "Please correct any grammar and spelling errors in the following text.",
        Wording = "Please improve the grammar and wording of the following text.",
        Concise = "Please rewrite the following text to make it more concise.",
        -- Custom Satanic prompts
        SatanicCode = "Rewrite this code with dark, occult-themed variable names and comments. Make it hellishly efficient! ⸸",
        SummonBug = "Find the demons (bugs) lurking in this code and exorcise them! 👹",
        DarkRefactor = "Refactor this code as if summoning dark powers. Make it elegant and sinister! ⛧",
      },
      auto_follow_cursor = false,
      show_folds = true,
      mappings = {
        complete = {
          detail = "Use @<Tab> or /<Tab> for options.",
          insert = "<Tab>",
        },
        close = {
          normal = "q",
          insert = "<C-c>"
        },
        reset = {
          normal = "<C-r>",
          insert = "<C-r>"
        },
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-s>"
        },
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>"
        },
        yank_diff = {
          normal = "gy",
        },
        show_diff = {
          normal = "gd"
        },
        show_system_prompt = {
          normal = "gp"
        },
        show_user_selection = {
          normal = "gs"
        },
      },
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      local select = require("CopilotChat.select")
      
      chat.setup(opts)
      
      -- Custom selections (with safety)
      pcall(function()
        require("CopilotChat.integrations.cmp").setup()
      end)
      
      -- Register custom selections
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "copilot-*",
        callback = function()
          vim.opt_local.relativenumber = true
          vim.opt_local.number = true
        end,
      })
    end,
    keys = {
      -- Quick chat
      {
        "<leader>aa",
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            require("CopilotChat").ask(input, { selection = require("CopilotChat.select").buffer })
          end
        end,
        desc = "CopilotChat - Quick chat",
      },
      -- Show help
      { "<leader>ah", function() require("CopilotChat").ask("/COPILOT_HELP") end, desc = "CopilotChat - Help" },
      -- Show prompts
      { "<leader>ap", function() require("CopilotChat").ask("/COPILOT_GENERATE") end, desc = "CopilotChat - Prompt actions" },
      -- Chat with buffer
      { "<leader>ab", function() require("CopilotChat").ask("Explain this code", { selection = require("CopilotChat.select").buffer }) end, desc = "CopilotChat - Chat with buffer" },
      -- Chat with visual selection
      { "<leader>av", ":CopilotChatVisual<CR>", mode = "x", desc = "CopilotChat - Chat with selection" },
      -- Inline chat
      { "<leader>ai", ":CopilotChatInline<CR>", mode = "x", desc = "CopilotChat - Inline chat" },
      -- Fix code
      { "<leader>af", "<cmd>CopilotChatFixDiagnostic<cr>", desc = "CopilotChat - Fix diagnostic" },
      { "<leader>ar", "<cmd>CopilotChatReset<cr>", desc = "CopilotChat - Reset chat history" },
      { "<leader>aq", function() require("CopilotChat").close() end, desc = "CopilotChat - Close chat" },
      -- Toggle Copilot Chat Window
      { "<leader>at", "<cmd>CopilotChatToggle<cr>", desc = "CopilotChat - Toggle window" },
      -- Custom satanic prompts
      { "<leader>aS", function() require("CopilotChat").ask("/SatanicCode") end, mode = "x", desc = "CopilotChat - Satanic Code" },
      { "<leader>aD", function() require("CopilotChat").ask("/SummonBug") end, mode = "x", desc = "CopilotChat - Debug (Summon Bugs)" },
      { "<leader>aR", function() require("CopilotChat").ask("/DarkRefactor") end, mode = "x", desc = "CopilotChat - Dark Refactor" },
    },
  },

  -- Local AI with Ollama ⸸
  {
    "David-Kunz/gen.nvim",
    event = "VeryLazy",
    config = function()
      require('gen').setup({
        model = "codellama:7b", -- Default local model
        host = "localhost",
        port = "11434",
        quit_map = "q",
        retry_map = "<c-r>",
        init = function(options) 
          pcall(io.popen, "ollama serve > /dev/null 2>&1 &") 
        end,
        command = function(options)
          return "ollama run " .. options.model .. " '" .. options.prompt .. "'"
        end,
        display_mode = "split",
        show_prompt = false,
        show_model = true,
        no_auto_close = false,
        debug = false
      })
    end,
    keys = {
      { "<leader>al", ":Gen<CR>", mode = { "n", "v" }, desc = "Local AI - Generate" },
      { "<leader>ac", function() 
          vim.ui.select({"codellama:7b", "llama3.1:8b", "deepseek-coder:6.7b", "codeqwen:7b"}, {
            prompt = "Select local model:",
          }, function(choice)
            if choice then
              require('gen').model = choice
              vim.notify("🤖 Switched to " .. choice, vim.log.levels.INFO)
            end
          end)
        end, desc = "Local AI - Switch model" },
      { "<leader>aE", ":Gen Enhance_Code<CR>", mode = { "n", "v" }, desc = "Local AI - Enhance code" },
      { "<leader>ax", ":Gen Fix_Code<CR>", mode = { "n", "v" }, desc = "Local AI - Fix code" },
      { "<leader>ad", ":Gen Generate_Docs<CR>", mode = { "n", "v" }, desc = "Local AI - Generate docs" },
    },
  },

  -- Advanced Local AI with Ollama.nvim
  {
    "nomnivore/ollama.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      model = "codellama:7b",
      url = "http://127.0.0.1:11434",
      serve = {
        on_start = false,
        command = "ollama",
        args = {"serve"},
        stop_command = "pkill",
        stop_args = {"-SIGTERM", "ollama"},
      }
    },
    keys = {
      {
        "<leader>ao",
        ":<c-u>lua require('ollama').prompt()<cr>",
        desc = "Ollama - Prompt",
        mode = { "n", "v" },
      },
      {
        "<leader>aO",
        ":<c-u>lua require('ollama').prompt('Generate_Code')<cr>",
        desc = "Ollama - Generate Code",
        mode = { "n", "v" },
      },
    }
  },

  -- Local Codeium (Free Alternative to Copilot for completion)
  {
    "Exafunction/codeium.vim",
    enabled = false, -- Enable this if you want local code completion alternative
    event = "InsertEnter",
    config = function()
      vim.g.codeium_disable_bindings = 1
      vim.keymap.set("i", "<C-g>", function() return vim.fn["codeium#Accept"]() end, { expr = true })
      vim.keymap.set("i", "<C-;>", function() return vim.fn["codeium#CycleCompletions"](1) end, { expr = true })
      vim.keymap.set("i", "<C-,>", function() return vim.fn["codeium#CycleCompletions"](-1) end, { expr = true })
      vim.keymap.set("i", "<C-x>", function() return vim.fn["codeium#Clear"]() end, { expr = true })
    end,
  },

  -- Local AI Chat Interface
  {
    "gsuuon/model.nvim",
    event = "VeryLazy",
    config = function()
      require('model').setup({
        provider = 'ollama',
        options = {
          url = 'http://localhost:11434',
          model = 'codellama:7b',
        },
        chat = {
          welcome_message = "⸸ Welcome to Local AI Hell ⸸",
          system_prompt = "You are a helpful coding assistant with a dark sense of humor. Use occult themes in your responses when appropriate.",
        },
        prompts = {
          code_review = {
            provider = 'ollama',
            options = { model = 'codellama:7b' },
            system = 'Review this code and provide suggestions for improvement.',
            prompt = 'Code:\n```{{filetype}}\n{{selection}}\n```\nReview:'
          },
          explain = {
            provider = 'ollama',
            options = { model = 'codellama:7b' },
            system = 'Explain how this code works in detail.',
            prompt = 'Code:\n```{{filetype}}\n{{selection}}\n```\nExplanation:'
          },
          fix = {
            provider = 'ollama',
            options = { model = 'codellama:7b' },
            system = 'Fix any bugs or issues in this code.',
            prompt = 'Code:\n```{{filetype}}\n{{selection}}\n```\nFixed version:'
          },
          docs = {
            provider = 'ollama',
            options = { model = 'codellama:7b' },
            system = 'Generate documentation for this code.',
            prompt = 'Code:\n```{{filetype}}\n{{selection}}\n```\nDocumentation:'
          },
          -- Satanic prompts for local AI
          satanic_code = {
            provider = 'ollama',
            options = { model = 'codellama:7b' },
            system = 'Rewrite code with dark, occult-themed variable names and comments. Make it hellishly efficient!',
            prompt = 'Code:\n```{{filetype}}\n{{selection}}\n```\nDark version:'
          }
        }
      })
    end,
    keys = {
      { "<leader>am", ":Model<CR>", mode = { "n", "v" }, desc = "Model - Local AI Chat" },
      { "<leader>ar", ":Model code_review<CR>", mode = { "v" }, desc = "Model - Code Review" },
      { "<leader>ae", ":Model explain<CR>", mode = { "v" }, desc = "Model - Explain Code" },
      { "<leader>aF", ":Model fix<CR>", mode = { "v" }, desc = "Model - Fix Code" },
      { "<leader>aD", ":Model docs<CR>", mode = { "v" }, desc = "Model - Generate Docs" },
      { "<leader>aS", ":Model satanic_code<CR>", mode = { "v" }, desc = "Model - Satanic Code" },
    }
  }
} 