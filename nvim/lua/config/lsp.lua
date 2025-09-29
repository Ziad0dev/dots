-- Plugin declarations (vim.pack is Neovim 0.11+; adjust if using another manager)
vim.pack.add {
  { src = 'https://github.com/neovim/nvim-lspconfig' },
  { src = 'https://github.com/mason-org/mason.nvim' },
  { src = 'https://github.com/mason-org/mason-lspconfig.nvim' },
  { src = 'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim' },
  -- Optional if you later want completion:
  -- { src = 'https://github.com/hrsh7th/nvim-cmp' },
  -- { src = 'https://github.com/hrsh7th/cmp-nvim-lsp' },
}

-- Mason core setup
require('mason').setup({
  ui = {
    border = 'rounded',
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗"
    }
  }
})

-- mason-lspconfig basic setup
require('mason-lspconfig').setup({
  ensure_installed = { "lua_ls" },
  automatic_installation = true,
})

-- Additional tools (formatters, linters, etc.)
require('mason-tool-installer').setup({
  ensure_installed = {
    "lua_ls",
    "stylua",
  },
  auto_update = false,
  run_on_start = true,
})

-- (Optional) Enhanced capabilities if using nvim-cmp later
-- local capabilities = vim.lsp.protocol.make_client_capabilities()
-- local ok_cmp, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
-- if ok_cmp then
--   capabilities = cmp_lsp.default_capabilities(capabilities)
-- end

-- on_attach: runs after a language server successfully attaches to a buffer
local function on_attach(client, bufnr)
  -- Example keymaps (buffer-local)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end

  map('n', 'K', vim.lsp.buf.hover, 'LSP Hover')
  map('n', 'gd', vim.lsp.buf.definition, 'Goto Definition')
  map('n', 'gD', vim.lsp.buf.declaration, 'Goto Declaration')
  map('n', 'gi', vim.lsp.buf.implementation, 'Goto Implementation')
  map('n', 'gr', vim.lsp.buf.references, 'References')
  map('n', '<leader>rn', vim.lsp.buf.rename, 'Rename Symbol')
  map('n', '<leader>ca', vim.lsp.buf.code_action, 'Code Action')
  map('n', '<leader>f', function()
    vim.lsp.buf.format({ async = true })
  end, 'Format Buffer')

  -- You can disable semantic tokens if you see highlight oddities:
  -- if client.server_capabilities.semanticTokensProvider then
  --   client.server_capabilities.semanticTokensProvider = nil
  -- end
end

-- lua_ls specific settings
local lua_ls_settings = {
  Lua = {
    runtime = {
      version = 'LuaJIT',
    },
    diagnostics = {
      globals = { 'vim', 'require' },
      -- disable = { 'lowercase-global' }, -- example if you want fewer warnings
    },
    workspace = {
      library = vim.api.nvim_get_runtime_file("", true),
      checkThirdParty = false, -- avoids prompts
    },
    format = {
      enable = false, -- you can use stylua externally
    },
    telemetry = {
      enable = false,
    },
    completion = {
      callSnippet = "Replace",
    },
    hint = {
      enable = true,
    },
  },
}

-- Newer API path (Neovim nightly) uses vim.lsp.config + vim.lsp.start
-- If you are on stable, stick to require('lspconfig').lua_ls.setup({...})
local has_new_api = vim.lsp and vim.lsp.config
if has_new_api then
  vim.lsp.config('lua_ls', {
    cmd = { 'lua-language-server' },
    settings = lua_ls_settings,
    on_attach = on_attach,
    -- capabilities = capabilities,
    single_file_support = true,
  })
  -- Auto-start for Lua buffers (if not already managed by something else)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "lua" },
    callback = function(args)
      vim.lsp.start(vim.lsp.get_configs().lua_ls)
    end,
  })
else
  -- Fallback to traditional lspconfig usage
  require('lspconfig').lua_ls.setup({
    settings = lua_ls_settings,
    on_attach = on_attach,
    -- capabilities = capabilities,
  })
end
