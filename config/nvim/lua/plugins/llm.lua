
return {
  {
    "ggml-org/llama.vim",
    event = "InsertEnter",
    init = function()
      vim.g.llama_config = {

        endpoint = "http://127.0.0.1:8012/infill",
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
        chat = { adapter = "llama-server" },
        inline = { adapter = "llama-server" },
        cmd = { adapter = "llama-server" },
      },
    },
  },
}
