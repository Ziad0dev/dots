-- ⸸ LSP Source Wrapper for nvim-cmp ⸸
-- This wrapper ensures proper buffer parameter handling

local M = {}

function M.setup()
  -- Patch vim.lsp.buf_request and related functions to handle function parameters safely
  local original_buf_request = vim.lsp.buf_request
  
  vim.lsp.buf_request = function(bufnr, method, params, handler, config)
    -- Ensure bufnr is always a valid number
    if type(bufnr) == "function" then
      bufnr = vim.api.nvim_get_current_buf()
    elseif type(bufnr) ~= "number" then
      bufnr = tonumber(bufnr) or vim.api.nvim_get_current_buf()
    end
    
    return original_buf_request(bufnr, method, params, handler, config)
  end
  
  if vim.lsp.buf_request_all then
    local original_buf_request_all = vim.lsp.buf_request_all
    
    vim.lsp.buf_request_all = function(bufnr, method, params, handler)
      -- Ensure bufnr is always a valid number
      if type(bufnr) == "function" then
        bufnr = vim.api.nvim_get_current_buf()
      elseif type(bufnr) ~= "number" then
        bufnr = tonumber(bufnr) or vim.api.nvim_get_current_buf()
      end
      
      return original_buf_request_all(bufnr, method, params, handler)
    end
  end

  -- Patch the LSP client request method at the module level
  vim.defer_fn(function()
    local success, client_module = pcall(require, 'vim.lsp.client')
    if success and client_module then
      -- Patch the client class if it exists
      local client_mt = getmetatable(client_module) or {}
      local original_request = client_mt.request or (client_module.Client and client_module.Client.request)
      
      if original_request then
        local function patched_request(self, method, params, handler, bufnr)
          -- Fix bufnr if it's a function
          if bufnr and type(bufnr) == "function" then
            bufnr = vim.api.nvim_get_current_buf()
          elseif bufnr and type(bufnr) ~= "number" then
            bufnr = tonumber(bufnr) or vim.api.nvim_get_current_buf()
          end
          
          return original_request(self, method, params, handler, bufnr)
        end
        
        if client_mt.request then
          client_mt.request = patched_request
        elseif client_module.Client then
          client_module.Client.request = patched_request
        end
      end
    end
  end, 50)
end

return M
