-- ============================================================================
-- TREESITTER (master branch — stable)
-- ============================================================================

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    main = "nvim-treesitter.configs",
    opts = {
      ensure_installed = {
        "lua", "vim", "vimdoc", "query",
        "bash", "fish",
        "python", "rust", "c", "cpp",
        "javascript", "typescript", "tsx", "json", "jsonc", "yaml", "toml",
        "nix", "markdown", "markdown_inline", "html", "css",
        "git_config", "gitcommit", "gitignore", "diff", "regex",
      },
      auto_install = false,
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          node_decremental = "<bs>",
        },
      },
    },
  },
}
