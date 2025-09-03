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
      
      -- Ensure we have valid buffer and client
      if not client or not buffer or type(buffer) == "function" then
        return
      end
      
      -- Ensure buffer is a valid number
      if type(buffer) ~= "number" then
        buffer = tonumber(buffer) or vim.api.nvim_get_current_buf()
      end
      
      pcall(on_attach, client, buffer)
    end,
  })
end

function M.setup_keymaps(client, buffer)
  -- Ensure buffer is a valid number
  if not buffer or type(buffer) == "function" then
    buffer = vim.api.nvim_get_current_buf()
  end
  if type(buffer) ~= "number" then
    buffer = tonumber(buffer) or vim.api.nvim_get_current_buf()
  end

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
  -- Ensure bufnr is valid
  if not bufnr or type(bufnr) == "function" then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if type(bufnr) ~= "number" then
    bufnr = tonumber(bufnr) or vim.api.nvim_get_current_buf()
  end
  
  if client and client.supports_method and client.supports_method("textDocument/inlayHint") then
    -- Only enable inlay hints if the API exists (Neovim 0.10+)
    if vim.lsp.inlay_hint and vim.lsp.inlay_hint.enable then
      pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
    end
  end
end

-- ⸸ Setup completion (disabled - using nvim-cmp instead)
function M.setup_completion(client, bufnr)
  -- Completion handled by nvim-cmp plugin
  -- Do not enable native LSP completion to avoid conflicts
end

-- ⸸ Setup semantic tokens highlighting
function M.setup_semantic_tokens(client, bufnr)
  -- Ensure bufnr is valid
  if not bufnr or type(bufnr) == "function" then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if type(bufnr) ~= "number" then
    bufnr = tonumber(bufnr) or vim.api.nvim_get_current_buf()
  end
  
  if client and client.supports_method and client.supports_method("textDocument/semanticTokens/full") then
    -- Only enable semantic tokens if the API exists (Neovim 0.9+)
    if vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.start then
      pcall(vim.lsp.semantic_tokens.start, bufnr, client.id)
    end
  end
end

-- ⸸ Modern LSP configuration using traditional lspconfig
function M.configure_server(name, config)
  -- Use traditional lspconfig setup
  local lspconfig = require("lspconfig")
  if lspconfig[name] then
    pcall(lspconfig[name].setup, config)
  end
end

-- ⸸ Helper function to get LSP status (traditional)
function M.get_status()
  local clients = vim.lsp.get_active_clients()
  if #clients == 0 then
    return "No LSP clients"
  end
  
  local names = {}
  for _, client in ipairs(clients) do
    table.insert(names, client.name)
  end
  return table.concat(names, ", ")
end

-- ⸸ Helper function to restart LSP
function M.restart_server(name)
  local clients = vim.lsp.get_active_clients()
  for _, client in ipairs(clients) do
    if client.name == name then
      client.stop()
      vim.defer_fn(function()
        vim.cmd("edit") -- Trigger LSP restart
      end, 100)
      break
    end
  end
end

return M
