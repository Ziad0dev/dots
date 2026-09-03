return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()

      vim.diagnostic.config({
        severity_sort = true,
        float = { border = "rounded", source = true },
        virtual_text = { prefix = "▸" },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN]  = " ",
            [vim.diagnostic.severity.INFO]  = " ",
            [vim.diagnostic.severity.HINT]  = " ",
          },
        },
      })

      local caps = require("cmp_nvim_lsp").default_capabilities()
      vim.lsp.config("*", { capabilities = caps })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("reaper_lsp_attach", { clear = true }),
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)

          if client and client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
          end

          if client and client:supports_method("textDocument/inlayHint") then
            pcall(vim.lsp.inlay_hint.enable, true, { bufnr = ev.buf })
          end

          local function m(keys, fn, desc)
            vim.keymap.set("n", keys, fn, { buffer = ev.buf, desc = "LSP: " .. desc })
          end
          m("gd", function() Snacks.picker.lsp_definitions() end, "Definition")
          m("gD", vim.lsp.buf.declaration, "Declaration")
          m("gi", function() Snacks.picker.lsp_implementations() end, "Implementation")
          m("gR", function() Snacks.picker.lsp_references() end, "References")
          m("gy", function() Snacks.picker.lsp_type_definitions() end, "Type definition")
          m("K", vim.lsp.buf.hover, "Hover")
          m("<leader>rn", vim.lsp.buf.rename, "Rename")
          m("<leader>ca", vim.lsp.buf.code_action, "Code action")
          m("<leader>cf", function() vim.lsp.buf.format({ async = true }) end, "Format")
        end,
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim", "Snacks" } },
            workspace = { checkThirdParty = false },
            hint = { enable = true },
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.config("nixd", {
        settings = {
          nixd = {
            formatting = { command = { "nixfmt" } },
            nixpkgs = { expr = "import <nixpkgs> { }" },
          },
        },
      })

      vim.lsp.config("pyright", {
        settings = {
          pyright = { disableOrganizeImports = true },
          python = {
            analysis = {
              ignore = { "*" },
              typeCheckingMode = "standard",
            },
          },
        },
      })

      vim.lsp.config("tinymist", {
        settings = {

          exportPdf = "never",
          formatterMode = "typstyle",
          formatterPrintWidth = 90,
          semanticTokens = "disable",
        },
      })

      vim.lsp.config("texlab", {
        settings = {
          texlab = {
            build = { onSave = false, forwardSearchAfter = false },
            chktex = { onOpenAndSave = true, onEdit = false },
            diagnosticsDelay = 300,
          },
        },
      })

      vim.lsp.config("rust_analyzer", {
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = { command = "clippy" },
            inlayHints = { closureReturnTypeHints = { enable = "with_block" } },
          },
        },
      })

      local servers = {
        lua_ls = "lua-language-server",
        pyright = "pyright",
        ts_ls = "typescript-language-server",
        rust_analyzer = "rust-analyzer",
        nixd = "nixd",
        zls = "zls",
        clangd = "clangd",
        ruff = "ruff",
        tinymist = "tinymist",
        texlab = "texlab",

      }
      for server, bin in pairs(servers) do
        if vim.fn.executable(bin) == 1 then
          vim.lsp.enable(server)
        end
      end
    end,
  },
}
