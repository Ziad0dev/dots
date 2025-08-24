-- ⸸ LSP Configuration Utilities ⸸

local M = {}

M._keys = nil

function M.get_keys()
  if M._keys then
    return M._keys
  end
  
  -- Modern keymaps following Neovim 0.11+ standards
  M._keys = {
    -- Diagnostics
    { "<leader>cd", vim.diagnostic.open_float, desc = "Line Diagnostics" },
    { "<leader>cl", "<cmd>LspInfo<cr>", desc = "Lsp Info" },
    { "[d", vim.diagnostic.goto_prev, desc = "Previous Diagnostic" },
    { "]d", vim.diagnostic.goto_next, desc = "Next Diagnostic" },
    { "<leader>cq", vim.diagnostic.setloclist, desc = "Diagnostic Quickfix" },
    
    -- Navigation - using modern capability names
    { "gd", vim.lsp.buf.definition, desc = "Goto Definition", has = "definitionProvider" },
    { "gr", vim.lsp.buf.references, desc = "References", has = "referencesProvider" },
    { "gD", vim.lsp.buf.declaration, desc = "Goto Declaration", has = "declarationProvider" },
    { "gI", vim.lsp.buf.implementation, desc = "Goto Implementation", has = "implementationProvider" },
    { "gy", vim.lsp.buf.type_definition, desc = "Goto T[y]pe Definition", has = "typeDefinitionProvider" },
    { "gO", vim.lsp.buf.document_symbol, desc = "Document Symbols", has = "documentSymbolProvider" },
    
    -- Information
    { "K", vim.lsp.buf.hover, desc = "Hover", has = "hoverProvider" },
    { "gK", vim.lsp.buf.signature_help, desc = "Signature Help", has = "signatureHelpProvider" },
    { "<c-s>", vim.lsp.buf.signature_help, mode = "i", desc = "Signature Help", has = "signatureHelpProvider" },
    
    -- Actions
    { "<leader>ca", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" }, has = "codeActionProvider" },
    { "<leader>cA", function()
        vim.lsp.buf.code_action({
          context = {
            only = { "source" },
            diagnostics = {},
          },
        })
      end, desc = "Source Action", has = "codeActionProvider" },
    { "<leader>cr", vim.lsp.buf.rename, desc = "Rename", has = "renameProvider" },
    
    -- Formatting
    { "<leader>cf", function()
        vim.lsp.buf.format({ 
          async = true,
          timeout_ms = 3000,
          filter = function(client)
            -- Exclude certain servers from formatting
            local exclude = { "tsserver", "typescript-tools", "lua_ls" }
            return not vim.tbl_contains(exclude, client.name)
          end,
        })
      end, desc = "Format Document", has = "documentFormattingProvider" },
      
    -- Type hierarchy (modern LSP feature)
    { "<leader>cth", vim.lsp.buf.typehierarchy, desc = "Type Hierarchy", has = "typeHierarchyProvider" },
    
    -- Selection range (incremental selection)
    { "an", vim.lsp.buf.selection_range, desc = "Outer Selection", mode = "v", has = "selectionRangeProvider" },
    { "in", vim.lsp.buf.selection_range, desc = "Inner Selection", mode = "v", has = "selectionRangeProvider" },
  }
  
  return M._keys
end

function M.on_attach(on_attach)
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("SatanicLspAttach", { clear = true }),
    callback = function(args)
      local buffer = args.buf
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        on_attach(client, buffer)
      end
    end,
  })
end

function M.setup_keymaps(client, buffer)
  local keymaps = M.get_keys()

  for _, keymap in ipairs(keymaps) do
    local opts = {
      buffer = buffer,
      silent = true,
      noremap = true,
    }
    
    -- Copy all options except special ones
    for k, v in pairs(keymap) do
      if type(k) ~= "number" and k ~= "mode" and k ~= "has" then
        opts[k] = v
      end
    end
    
    local modes = keymap.mode or "n"
    local has_capability = true
    
    -- Check if server has required capability using supports_method
    if keymap.has then
      -- Convert capability names to method names for supports_method
      local method_map = {
        definitionProvider = "textDocument/definition",
        referencesProvider = "textDocument/references",
        declarationProvider = "textDocument/declaration",
        implementationProvider = "textDocument/implementation",
        typeDefinitionProvider = "textDocument/typeDefinition",
        documentSymbolProvider = "textDocument/documentSymbol",
        hoverProvider = "textDocument/hover",
        signatureHelpProvider = "textDocument/signatureHelp",
        codeActionProvider = "textDocument/codeAction",
        renameProvider = "textDocument/rename",
        documentFormattingProvider = "textDocument/formatting",
        typeHierarchyProvider = "textDocument/prepareTypeHierarchy",
        selectionRangeProvider = "textDocument/selectionRange",
      }
      
      local method = method_map[keymap.has]
      if method then
        has_capability = client:supports_method(method)
      else
        has_capability = client.server_capabilities[keymap.has] == true
      end
    end
    
    if has_capability then
      vim.keymap.set(modes, keymap[1], keymap[2], opts)
    end
  end
end

function M.setup_autoformat(opts)
  opts = opts or {}
  
  if not opts.autoformat then
    return
  end

  local format_augroup = vim.api.nvim_create_augroup("SatanicLspAutoFormat", { clear = true })
  
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = format_augroup,
    pattern = "*",
    callback = function(event)
      local bufnr = event.buf
      local filetype = vim.bo[bufnr].filetype
      
      -- Skip certain filetypes
      local ignore_filetypes = { "terraform", "markdown" }
      if vim.tbl_contains(ignore_filetypes, filetype) then
        return
      end
      
      -- Get active LSP clients for this buffer (modern API)
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      local has_formatter = false
      
      for _, client in ipairs(clients) do
        if client:supports_method("textDocument/formatting") then
          has_formatter = true
          break
        end
      end

      if has_formatter then
        vim.lsp.buf.format({
          bufnr = bufnr,
          async = false,
          timeout_ms = 3000,
          filter = function(client)
            -- Exclude certain servers from formatting
            local exclude_formatters = { 
              "tsserver", 
              "typescript-tools",
              "lua_ls", -- Use stylua instead
              "jsonls",  -- Use prettier instead
            }
            return not vim.tbl_contains(exclude_formatters, client.name)
          end,
        })
      end
    end,
  })
end

-- ⸸ Enhanced diagnostic configuration with satanic icons
function M.setup_diagnostics(opts)
  opts = opts or {}
  
  local signs = {
    Error = "⸸",
    Warn = "⛧", 
    Hint = "🕯",
    Info = "☠",
  }
  
  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end

  vim.diagnostic.config(vim.tbl_deep_extend("force", {
    virtual_text = {
      prefix = "●",
      source = "if_many",
    },
    signs = {
      text = signs,
    },
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
      focusable = false,
      style = "minimal",
      border = "rounded",
      source = "if_many",
      header = "",
      prefix = "",
    },
  }, opts.diagnostics or {}))
end

-- ⸸ Setup inlay hints for supported servers
function M.setup_inlay_hints(client, bufnr)
  if client:supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

-- ⸸ Setup completion using modern completion API
function M.setup_completion(client, bufnr)
  if client:supports_method("textDocument/completion") then
    -- Enable modern LSP completion
    vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
  end
end

-- ⸸ Setup semantic tokens highlighting
function M.setup_semantic_tokens(client, bufnr)
  if client:supports_method("textDocument/semanticTokens/full") then
    vim.lsp.semantic_tokens.start(bufnr, client.id)
  end
end

-- ⸸ Modern LSP configuration using vim.lsp.config
function M.configure_server(name, config)
  -- Use the modern vim.lsp.config API
  vim.lsp.config(name, config)
end

-- ⸸ Enable servers using modern API
function M.enable_server(name)
  vim.lsp.enable(name)
end

-- ⸸ Unified setup function following modern patterns
function M.setup(opts)
  opts = opts or {}
  
  -- Setup global configurations
  M.setup_diagnostics(opts)
  M.setup_autoformat(opts)
  
  -- Setup global LSP defaults using modern config API
  vim.lsp.config("*", {
    capabilities = vim.tbl_deep_extend("force", 
      vim.lsp.protocol.make_client_capabilities(),
      opts.capabilities or {}
    ),
    root_markers = { ".git", ".hg", ".svn" },
  })
  
  -- Setup LspAttach handler
  M.on_attach(function(client, buffer)
    M.setup_keymaps(client, buffer)
    M.setup_inlay_hints(client, buffer)
    M.setup_completion(client, buffer)
    M.setup_semantic_tokens(client, buffer)
    
    -- Call user's on_attach if provided
    if opts.on_attach then
      opts.on_attach(client, buffer)
    end
  end)
  
  -- Configure specific servers if provided
  if opts.servers then
    for name, config in pairs(opts.servers) do
      M.configure_server(name, config)
      if config.enable ~= false then
        M.enable_server(name)
      end
    end
  end
end

-- ⸸ Helper function to get LSP status (modern)
function M.get_status()
  return vim.lsp.status()
end

-- ⸸ Helper function to restart LSP
function M.restart_server(name)
  vim.lsp.enable(name, false)
  vim.defer_fn(function()
    vim.lsp.enable(name, true)
  end, 100)
end

return M
