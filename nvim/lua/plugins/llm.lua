-- lua/plugins/llm.lua — local inference wiring against llm.nix's servers.
-- Drop into lua/plugins/ alongside the rest; lazy.nvim picks it up.
--
-- llama.vim  → ghost-text FIM completion  → needs llama-fim  (:8012)
-- codecompanion → chat / inline edits     → needs llama-chat (:8080)
-- Start them on demand: `systemctl --user start llama-fim llama-chat`.

return {
  {
    "ggml-org/llama.vim",
    event = "InsertEnter",
    init = function()
      vim.g.llama_config = {
        -- current option name is endpoint_fim; older releases used
        -- endpoint. Setting both is harmless and survives either version.
        endpoint = "http://127.0.0.1:8012/infill",
        endpoint_fim = "http://127.0.0.1:8012/infill",
        auto_fim = true,
        show_info = 0, -- no stats line; set 1 if you want ctx/timing info
        -- defaults: <Tab> accept suggestion, <S-Tab> accept first line
      }
    end,
  },

  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      -- needs the markdown + markdown_inline parsers; add them to your
      -- treesitter ensure_installed if they aren't there already
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
                api_key = "none", -- llama-server ignores it; must be non-empty
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = { default = "qwen3.5-9b-local" }, -- label only
              },
            })
          end,
        },
      },
      -- `interactions` on current codecompanion; if your pinned version is
      -- older and complains, the key was previously named `strategies`.
      interactions = {
        chat = { adapter = "llama-server" },
        inline = { adapter = "llama-server" },
        cmd = { adapter = "llama-server" },
      },
    },
  },
}
