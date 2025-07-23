return {
  -- Markdown Preview in Browser
  {
    "iamcco/markdown-preview.nvim", 
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
    config = function()
      -- Auto-detect browser
      local function detect_browser()
        local browsers = {'firefox', 'google-chrome', 'chromium-browser', 'brave-browser'}
        for _, browser in ipairs(browsers) do
          if vim.fn.executable(browser) == 1 then
            return browser
          end
        end
        return ''
      end
      
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_command_for_global = 0
      vim.g.mkdp_open_to_the_world = 0
      vim.g.mkdp_open_ip = ''
      vim.g.mkdp_browser = detect_browser()
      vim.g.mkdp_echo_preview_url = 0
      vim.g.mkdp_browserfunc = ''
      vim.g.mkdp_preview_options = {
        mkit = {},
        katex = {},
        uml = {},
        maid = {},
        disable_sync_scroll = 0,
        sync_scroll_type = 'middle',
        hide_yaml_meta = 1,
        sequence_diagrams = {},
        flowchart_diagrams = {},
        content_editable = false,
        disable_filename = 0
      }
      vim.g.mkdp_markdown_css = ''
      vim.g.mkdp_highlight_css = ''
      vim.g.mkdp_port = ''
      vim.g.mkdp_page_title = '⸸ ${name} ⸸'
      vim.g.mkdp_filetypes = {'markdown'}
    end,
  },
  
  -- Terminal-based markdown preview with glow
  {
    "ellisonleao/glow.nvim",
    config = function()
      require('glow').setup({
        glow_path = "/usr/local/bin/glow", -- explicit path to glow binary
        install_path = "~/.local/bin", -- default path for installing glow binary
        border = "rounded", -- floating window border config
        style = "dark", -- filled automatically with your current editor background, also you can pass 'light'
        pager = false,
        width = 120,
        height = 100,
        width_ratio = 0.8, -- maximum width of the Glow window compared to the nvim window size (overrides `width`)
        height_ratio = 0.8,
      })
    end,
    cmd = "Glow",
  },
  
  -- Peek.nvim - another markdown previewer
  {
    "toppair/peek.nvim",
    event = { "VeryLazy" },
    build = "deno task --quiet build:fast",
    config = function()
      require("peek").setup({
        auto_load = true,         -- whether to automatically load preview when entering markdown buffer
        close_on_bdelete = true,  -- close preview window on buffer delete
        syntax = true,            -- enable syntax highlighting, affects performance
        theme = 'dark',           -- 'dark' or 'light'
        update_on_change = true,
        app = 'webview',          -- 'webview', 'browser', string or a table of strings
        filetype = { 'markdown' }, -- list of filetypes to recognize as markdown
        throttle_at = 200000,     -- start throttling when file exceeds this amount of bytes in size
        throttle_time = 'auto',   -- minimum amount of time in milliseconds that has to pass before updating the preview
      })
    end,
  },
  
  -- Additional markdown utilities
  {
    "preservim/vim-markdown",
    ft = "markdown",
    config = function()
      vim.g.vim_markdown_folding_disabled = 1
      vim.g.vim_markdown_conceal = 0
      vim.g.vim_markdown_conceal_code_blocks = 0
      vim.g.vim_markdown_math = 1
      vim.g.vim_markdown_frontmatter = 1
      vim.g.vim_markdown_strikethrough = 1
    end,
  },
} 