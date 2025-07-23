-- ⸸ LSP Configuration Utilities ⸸

local M = {}

M._keys = nil

function M.get_keys()
  if M._keys then
    return M._keys
  end
  M._keys = {
    { "<leader>cd", vim.diagnostic.open_float, desc = "Line Diagnostics" },
    { "<leader>cl", "<cmd>LspInfo<cr>", desc = "Lsp Info" },
    { "gd", vim.lsp.buf.definition, desc = "Goto Definition", has = "definition" },
    { "gr", vim.lsp.buf.references, desc = "References" },
    { "gD", vim.lsp.buf.declaration, desc = "Goto Declaration" },
    { "gI", vim.lsp.buf.implementation, desc = "Goto Implementation", has = "implementation" },
    { "gy", vim.lsp.buf.type_definition, desc = "Goto T[y]pe Definition" },
    { "K", vim.lsp.buf.hover, desc = "Hover" },
    { "gK", vim.lsp.buf.signature_help, desc = "Signature Help", has = "signatureHelp" },
    { "<c-k>", vim.lsp.buf.signature_help, mode = "i", desc = "Signature Help", has = "signatureHelp" },
    { "<leader>ca", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" }, has = "codeAction" },
    { "<leader>cA", function()
        vim.lsp.buf.code_action({
          context = {
            only = {
              "source",
            },
            diagnostics = {},
          },
        })
      end, desc = "Source Action", has = "codeAction" },
    { "<leader>cr", vim.lsp.buf.rename, desc = "Rename", has = "rename" },
  }
  return M._keys
end

function M.on_attach(on_attach)
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local buffer = args.buf
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      on_attach(client, buffer)
    end,
  })
end

function M.setup_keymaps(client, buffer)
  local Keys = require("lazy.core.handler.keys")
  local keymaps = M.get_keys()

  for _, keymap in ipairs(keymaps) do
    local opts = {}
    for k, v in pairs(keymap) do
      if type(k) ~= "number" and k ~= "mode" and k ~= "has" then
        opts[k] = v
      end
    end
    opts.has = nil
    opts.silent = opts.silent ~= false
    opts.buffer = buffer

    local modes = keymap.mode or "n"
    if keymap.has and not client.server_capabilities[keymap.has] then
      -- do nothing
    else
      vim.keymap.set(modes, keymap[1], keymap[2], opts)
    end
  end
end

function M.setup_autoformat(opts)
  -- Enable autoformat (if enabled)
  if opts.autoformat then
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("LspFormat", {}),
      callback = function(event)
        local ignore_filetypes = { "terraform" }
        if vim.tbl_contains(ignore_filetypes, vim.bo[event.buf].filetype) then
          return
        end
        
        -- Check if buffer has formatters available
        local has_formatter = false
        local clients = vim.lsp.get_active_clients({ bufnr = event.buf })
        for _, client in ipairs(clients) do
          if client.server_capabilities.documentFormattingProvider then
            has_formatter = true
            break
          end
        end

        if has_formatter then
          vim.lsp.buf.format({
            bufnr = event.buf,
            timeout_ms = 3000,
            filter = function(c)
              return c.name ~= "tsserver" and c.name ~= "typescript-tools"
            end,
          })
        end
      end,
    })
  end
end

return M 