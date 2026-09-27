local no_save_format = { markdown = true, tex = true, plaintex = true }

return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>cf",
        function() require("conform").format({ async = true }) end,
        mode = { "n", "v" },
        desc = "Format",
      },
      {
        "<leader>uf",
        function()
          vim.g.autoformat = not vim.g.autoformat
          vim.notify("Format on save " .. (vim.g.autoformat and "on" or "off"))
        end,
        desc = "Toggle format on save",
      },
      {
        "<leader>uF",
        function()
          vim.b.autoformat = vim.b.autoformat == false
          vim.notify("Format on save (buffer) " .. (vim.b.autoformat and "on" or "off"))
        end,
        desc = "Toggle format on save (buffer)",
      },
    },
    init = function()
      vim.g.autoformat = true
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
    opts = {
      default_format_opts = { lsp_format = "fallback" },
      formatters_by_ft = {
        lua = { "stylua" },
        nix = { "nixfmt" },
        python = { "ruff_organize_imports", "ruff_format" },
        rust = { "rustfmt" },
        zig = { "zigfmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        fish = { "fish_indent" },
        toml = { "taplo" },
        typst = { "typstyle" },
        json = { "prettier" },
        jsonc = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        svelte = { "prettier" },
        vue = { "prettier" },
      },
      format_on_save = function(buf)
        if not vim.g.autoformat or vim.b[buf].autoformat == false then return end
        if no_save_format[vim.bo[buf].filetype] then return end
        return { timeout_ms = 1500 }
      end,
    },
  },
}
