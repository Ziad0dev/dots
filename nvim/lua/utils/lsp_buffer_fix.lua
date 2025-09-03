-- ⸸ Emergency LSP Buffer Fix ⸸
-- Patches the vim.validate function to handle function arguments gracefully

-- Store original validate function
local original_validate = vim.validate

-- Create a patched validate function
vim.validate = function(spec, opts)
  -- Iterate through spec and fix function arguments that should be numbers
  for key, value in pairs(spec) do
    if type(value) == "table" and #value >= 2 then
      local arg_value = value[1]
      local expected_type = value[2]
      
      -- If we're expecting a number but got a function, and the key suggests it's a buffer
      if expected_type == "number" and type(arg_value) == "function" and 
         (key:lower():match("buf") or key == "bufnr") then
        -- Replace the function with current buffer number
        value[1] = vim.api.nvim_get_current_buf()
      end
    end
  end
  
  -- Call original validate with potentially fixed arguments
  return original_validate(spec, opts)
end

return {}
