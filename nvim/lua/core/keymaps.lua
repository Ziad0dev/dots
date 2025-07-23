-- ⸸ Core Keymaps - Satanic Bindings ⸸

local keymap = vim.keymap.set

-- Better up/down with wrapped lines
keymap({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
keymap({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Move to window using <ctrl> + hjkl
keymap("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Resize window using <ctrl> + arrow keys
keymap("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
keymap("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
keymap("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
keymap("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Move Lines
keymap("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
keymap("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
keymap("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move line down" })
keymap("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move line up" })
keymap("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move line down" })
keymap("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move line up" })

-- Clear search with <esc>
keymap({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and clear hlsearch" })

-- Better indenting
keymap("v", "<", "<gv")
keymap("v", ">", ">gv")

-- Save file
keymap({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })

-- Buffers
keymap("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
keymap("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
keymap("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
keymap("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })
keymap("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
keymap("n", "<leader>`", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })

-- Quit
keymap("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

-- Satanic window management
keymap("n", "<leader>ww", "<C-W>p", { desc = "Other window" })
keymap("n", "<leader>wd", "<C-W>c", { desc = "Delete window" })
keymap("n", "<leader>w-", "<C-W>s", { desc = "Split window below" })
keymap("n", "<leader>w|", "<C-W>v", { desc = "Split window right" })
keymap("n", "<leader>-", "<C-W>s", { desc = "Split window below" })
keymap("n", "<leader>|", "<C-W>v", { desc = "Split window right" })

-- tabs
keymap("n", "<leader><tab>l", "<cmd>tablast<cr>", { desc = "Last Tab" })
keymap("n", "<leader><tab>f", "<cmd>tabfirst<cr>", { desc = "First Tab" })
keymap("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New Tab" })
keymap("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next Tab" })
keymap("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close Tab" })
keymap("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })

-- Diagnostics  
keymap("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
keymap("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })
keymap("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev Diagnostic" })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
keymap("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "Next search result" })
keymap("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
keymap("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
keymap("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "Prev search result" })
keymap("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
keymap("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })

-- Add undo break-points
keymap("i", ",", ",<c-g>u")
keymap("i", ".", ".<c-g>u")
keymap("i", ";", ";<c-g>u")

-- Command mode navigation
keymap("c", "<C-h>", "<Left>", { desc = "Left" })
keymap("c", "<C-l>", "<Right>", { desc = "Right" })
keymap("c", "<C-j>", "<Down>", { desc = "Down" })
keymap("c", "<C-k>", "<Up>", { desc = "Up" })

-- Terminal mode
keymap("t", "<esc><esc>", "<c-\\><c-n>", { desc = "Enter Normal Mode" })
keymap("t", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Go to left window" })
keymap("t", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Go to lower window" })
keymap("t", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Go to upper window" })
keymap("t", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Go to right window" })

-- Quickfix
keymap("n", "[q", vim.cmd.cprev, { desc = "Previous quickfix" })
keymap("n", "]q", vim.cmd.cnext, { desc = "Next quickfix" })

-- Satanic paste without losing register
keymap("x", "<leader>p", [["_dP]], { desc = "Paste without losing register" })

-- ⸸ Markdown Keymaps ⸸
keymap("n", "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", { desc = "Toggle Markdown Preview" })
keymap("n", "<leader>mg", "<cmd>Glow<cr>", { desc = "Glow Markdown Preview" })
keymap("n", "<leader>mz", function()
  local current_file = vim.fn.expand('%:p')
  if vim.bo.filetype ~= 'markdown' then
    vim.notify("⸸ Not a markdown file!", vim.log.levels.WARN)
    return
  end
  
  local pdf_file = vim.fn.expand('%:r') .. '.pdf'
  
  -- First, convert to PDF
  vim.notify("👹 Converting markdown to PDF...", vim.log.levels.INFO)
  
  -- Try XeLaTeX first (better Unicode support), fallback to wkhtmltopdf
  local function try_pandoc_xelatex()
    if vim.system then
      vim.system({'pandoc', current_file, '-o', pdf_file, '--pdf-engine=xelatex'}, {}, function(result)
        if result.code == 0 then
          vim.schedule(function()
            vim.notify("☠ PDF created with XeLaTeX! Opening in Zathura...", vim.log.levels.INFO)
            vim.system({'zathura', pdf_file}, { detach = true })
          end)
        else
          vim.schedule(function()
            vim.notify("⛧ XeLaTeX failed, trying wkhtmltopdf...", vim.log.levels.WARN)
            try_wkhtmltopdf()
          end)
        end
      end)
    else
      -- Fallback for older Neovim versions
      vim.fn.jobstart({'pandoc', current_file, '-o', pdf_file, '--pdf-engine=xelatex'}, {
        on_exit = function(_, exit_code)
          if exit_code == 0 then
            vim.notify("☠ PDF created with XeLaTeX! Opening in Zathura...", vim.log.levels.INFO)
            vim.fn.jobstart({'zathura', pdf_file}, { detach = true })
          else
            vim.notify("⛧ XeLaTeX failed, trying wkhtmltopdf...", vim.log.levels.WARN)
            try_wkhtmltopdf()
          end
        end,
      })
    end
  end
  
  local function try_wkhtmltopdf()
    -- Convert to HTML first, then to PDF with wkhtmltopdf
    local html_file = vim.fn.expand('%:r') .. '_temp.html'
    
    if vim.system then
      vim.system({'pandoc', current_file, '-o', html_file}, {}, function(result)
        if result.code == 0 then
          vim.system({'wkhtmltopdf', html_file, pdf_file}, {}, function(result2)
            vim.schedule(function()
              -- Clean up temp HTML file
              vim.fn.delete(html_file)
              if result2.code == 0 then
                vim.notify("☠ PDF created with wkhtmltopdf! Opening in Zathura...", vim.log.levels.INFO)
                vim.system({'zathura', pdf_file}, { detach = true })
              else
                vim.notify("⸸ All PDF conversion methods failed!", vim.log.levels.ERROR)
              end
            end)
          end)
        else
          vim.schedule(function()
            vim.notify("⸸ Failed to create temporary HTML!", vim.log.levels.ERROR)
          end)
        end
      end)
    else
      -- Fallback for older Neovim versions
      vim.fn.jobstart({'pandoc', current_file, '-o', html_file}, {
        on_exit = function(_, exit_code)
          if exit_code == 0 then
            vim.fn.jobstart({'wkhtmltopdf', html_file, pdf_file}, {
              on_exit = function(_, exit_code2)
                vim.fn.delete(html_file)
                if exit_code2 == 0 then
                  vim.notify("☠ PDF created with wkhtmltopdf! Opening in Zathura...", vim.log.levels.INFO)
                  vim.fn.jobstart({'zathura', pdf_file}, { detach = true })
                else
                  vim.notify("⸸ All PDF conversion methods failed!", vim.log.levels.ERROR)
                end
              end,
            })
          else
            vim.notify("⸸ Failed to create temporary HTML!", vim.log.levels.ERROR)
          end
        end,
      })
    end
  end
  
  -- Start with XeLaTeX
  try_pandoc_xelatex()
end, { desc = "Convert to PDF and open in Zathura" })

-- Simple PDF conversion without Unicode (backup option)
keymap("n", "<leader>mZ", function()
  local current_file = vim.fn.expand('%:p')
  if vim.bo.filetype ~= 'markdown' then
    vim.notify("⸸ Not a markdown file!", vim.log.levels.WARN)
    return
  end
  
  local pdf_file = vim.fn.expand('%:r') .. '_simple.pdf'
  vim.notify("🔥 Creating simple PDF (no emojis)...", vim.log.levels.INFO)
  
  if vim.system then
    vim.system({'pandoc', current_file, '-o', pdf_file, '--pdf-engine=pdflatex'}, {}, function(result)
      if result.code == 0 then
        vim.schedule(function()
          vim.notify("☠ Simple PDF created! Opening in Zathura...", vim.log.levels.INFO)
          vim.system({'zathura', pdf_file}, { detach = true })
        end)
      else
        vim.schedule(function()
          vim.notify("⸸ Simple PDF conversion failed too!", vim.log.levels.ERROR)
        end)
      end
    end)
  else
    vim.fn.jobstart({'pandoc', current_file, '-o', pdf_file, '--pdf-engine=pdflatex'}, {
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          vim.notify("☠ Simple PDF created! Opening in Zathura...", vim.log.levels.INFO)
          vim.fn.jobstart({'zathura', pdf_file}, { detach = true })
        else
          vim.notify("⸸ Simple PDF conversion failed too!", vim.log.levels.ERROR)
        end
      end,
    })
  end
end, { desc = "Simple PDF (no Unicode) + Zathura" })
keymap("n", "<leader>me", function()
  local current_file = vim.fn.expand('%:p')
  if vim.bo.filetype ~= 'markdown' then
    vim.notify("⸸ Not a markdown file!", vim.log.levels.WARN)
    return
  end
  
  -- Auto-detect browser
  local function detect_browser()
    local browsers = {'firefox', 'google-chrome', 'chromium-browser', 'brave-browser'}
    for _, browser in ipairs(browsers) do
      if vim.fn.executable(browser) == 1 then
        return browser
      end
    end
    return 'xdg-open'
  end
  
  local html_file = vim.fn.expand('%:r') .. '.html'
  local browser = detect_browser()
  
  vim.notify("👹 Converting markdown to HTML...", vim.log.levels.INFO)
  
  -- Use async conversion for HTML too
  if vim.system then
    vim.system({'pandoc', current_file, '-o', html_file}, {}, function(result)
      if result.code == 0 then
        vim.schedule(function()
          vim.notify(string.format("☠ HTML created! Opening with %s...", browser), vim.log.levels.INFO)
          vim.system({browser, html_file}, { detach = true })
        end)
      else
        vim.schedule(function()
          vim.notify("⸸ Failed to convert HTML: " .. (result.stderr or "Unknown error"), vim.log.levels.ERROR)
        end)
      end
    end)
  else
    -- Fallback for older Neovim versions
    local job_id = vim.fn.jobstart({'pandoc', current_file, '-o', html_file}, {
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          vim.notify(string.format("☠ HTML created! Opening with %s...", browser), vim.log.levels.INFO)
          vim.fn.jobstart({browser, html_file}, { detach = true })
        else
          vim.notify("⸸ Failed to convert HTML!", vim.log.levels.ERROR)
        end
      end,
    })
  end
end, { desc = "Convert to HTML and open" }) 