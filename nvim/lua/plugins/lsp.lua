-- ⸸ HAIL SATAN - Language Servers ⸸

return {
  -- Mason: LSP installer and manager
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
    build = ":MasonUpdate",
    opts = {
      ensure_installed = {
        "stylua",
        "shfmt",
        "lua-language-server",
        "typescript-language-server",
        "pyright",
        "rust-analyzer",
        "clangd",
        "gopls",
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)
      local mr = require("mason-registry")
      mr:on("package:install:success", function()
        vim.defer_fn(function()
          -- trigger FileType event to possibly load this newly installed LSP server
          require("lazy.core.handler.event").trigger({
            event = "FileType",
            buf = vim.api.nvim_get_current_buf(),
          })
        end, 100)
      end)
      local function ensure_installed()
        for _, tool in ipairs(opts.ensure_installed) do
          local p = mr.get_package(tool)
          if not p:is_installed() then
            p:install()
          end
        end
      end
      if mr.refresh then
        mr.refresh(ensure_installed)
      else
        ensure_installed()
      end
    end,
  },

  -- LSPConfig
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    opts = {
      -- options for vim.diagnostic.config()
      diagnostics = {
        underline = true,
        update_in_insert = false,
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
        },
        severity_sort = true,
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "⸸",
            [vim.diagnostic.severity.WARN] = "⛧",
            [vim.diagnostic.severity.HINT] = "☠",
            [vim.diagnostic.severity.INFO] = "🕯",
          },
        },
      },
      -- Enable this to enable the builtin LSP inlay hints on Neovim >= 0.10.0
      inlay_hints = { enabled = false },
      -- add any global capabilities here
      capabilities = {},
      -- Automatically format on save
      autoformat = true,
      -- options for vim.lsp.buf.format
      format = {
        formatting_options = nil,
        timeout_ms = nil,
      },
      -- LSP Server Settings
      servers = {
        lua_ls = {
          settings = {
            Lua = {
              workspace = {
                checkThirdParty = false,
              },
              completion = {
                callSnippet = "Replace",
              },
              telemetry = { enable = false },
              hint = {
                enable = true,
                arrayIndex = "Disable", -- "Enable" | "Auto" | "Disable"
                await = true,
                paramName = "Disable", -- "All" | "Literal" | "Disable"
                paramType = true,
                semicolon = "Disable", -- "All" | "SameLine" | "Disable"
                setType = false,
              },
            },
          },
        },
        pyright = {},
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
                runBuildScripts = true,
              },
              checkOnSave = {
                allFeatures = true,
                command = "clippy",
                extraArgs = { "--no-deps" },
              },
              procMacro = {
                enable = true,
                ignored = {
                  ["async-trait"] = { "async_trait" },
                  ["napi-derive"] = { "napi" },
                  ["async-recursion"] = { "async_recursion" },
                },
              },
            },
          },
        },
        ts_ls = {
          settings = {
            typescript = {
              inlayHints = {
                includeInlayParameterNameHints = "literal",
                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = false,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayEnumMemberValueHints = true,
              },
            },
            javascript = {
              inlayHints = {
                includeInlayParameterNameHints = "all",
                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = true,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayEnumMemberValueHints = true,
              },
            },
          },
        },
        clangd = {},
        gopls = {},
      },
      -- you can do any additional lsp server setup here
      setup = {},
    },
    config = function(_, opts)
      -- Setup diagnostics first
      vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

      -- Get LSP capabilities with nvim-cmp integration
      local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
      local capabilities = vim.tbl_deep_extend(
        "force",
        {},
        vim.lsp.protocol.make_client_capabilities(),
        has_cmp and cmp_nvim_lsp.default_capabilities() or {},
        opts.capabilities or {}
      )

      -- Global on_attach handler (safe execution)
      local function on_attach(client, bufnr)
        local has_config_lsp, config_lsp = pcall(require, "config.lsp")
        if has_config_lsp then
          pcall(config_lsp.setup_keymaps, client, bufnr)
          pcall(config_lsp.setup_inlay_hints, client, bufnr)
          pcall(config_lsp.setup_semantic_tokens, client, bufnr)
        end
      end

      -- Setup autoformat (safe execution)
      local has_config_lsp, config_lsp = pcall(require, "config.lsp")
      if has_config_lsp then
        pcall(config_lsp.setup_autoformat, opts)
      end

      -- Iterate over servers and use the new API
      for server, server_config in pairs(opts.servers) do
        local server_opts = vim.tbl_deep_extend("force", {
          capabilities = vim.deepcopy(capabilities),
        }, server_config or {})

        -- Setup on_attach as a hook for LspAttach event is cleaner,
        -- but for compatibility we can still pass it if the server supports it,
        -- though new vim.lsp.config usually relies on autocmds.
        -- We'll add an autocmd for this server to trigger on_attach logic
        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client and client.name == server then
              on_attach(client, args.buf)
            end
          end,
        })

        -- Handle custom setup functions
        if opts.setup[server] then
          if opts.setup[server](server, server_opts) then
            goto continue
          end
        elseif opts.setup["*"] then
          if opts.setup["*"](server, server_opts) then
            goto continue
          end
        end

        -- Use the NEW Neovim 0.11+ API
        -- This avoids 'require("lspconfig")' deprecation warnings
        if vim.lsp.config then
          vim.lsp.config(server, server_opts)
          vim.lsp.enable(server)
        else
          -- Fallback for older Neovim versions (just in case)
          local lspconfig = require("lspconfig")
          if lspconfig[server] then
             lspconfig[server].setup(server_opts)
          end
        end

        ::continue::
      end
    end,
  },
}
