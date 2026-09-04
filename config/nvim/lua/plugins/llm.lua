
return {
  {
    "ggml-org/llama.vim",
    event = "InsertEnter",
    init = function()
      vim.g.llama_config = {

        endpoint_fim = "http://127.0.0.1:8012/infill",
        auto_fim = true,
        show_info = 0,

      }
    end,
  },

  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",

    },
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
    keys = {
      { "<leader>cc", "<cmd>CodeCompanionChat Toggle<cr>", desc = "LLM chat" },
    },
    opts = {
      adapters = {
        http = {
          ["openrouter"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://openrouter.ai/api/v1",
                api_key = "cmd:secretspec get OPENROUTER_API_KEY",
                chat_url = "/chat/completions",
              },
              schema = {
                model = { default = "anthropic/claude-sonnet-4.5" },
              },
            })
          end,

          ["llama-server"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "http://127.0.0.1:8080",
                api_key = "none",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = { default = "qwen3.5-9b-local" },
              },
            })
          end,
        },
      },

      interactions = {
        chat = { adapter = "openrouter" },
        inline = { adapter = "llama-server" },
        cmd = { adapter = "openrouter" },
      },
    },
  },
}
