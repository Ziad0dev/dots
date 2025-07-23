-- ⸸ HAIL SATAN - Startup Screen ⸸

return {
  {
    "mhinz/vim-startify",
    config = function()
      vim.g.startify_custom_header = {
        '                                                                    ',
        '    ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗            ',
        '    ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║            ',
        '    ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║            ',
        '    ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║            ',
        '    ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║            ',
        '    ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝            ',
        '                                                                    ',
        '                       ███████╗██████╗  ██████╗ ███╗   ███╗                          ',
        '                       ██╔════╝██╔══██╗██╔═══██╗████╗ ████║                          ',
        '                       █████╗  ██████╔╝██║   ██║██╔████╔██║                          ',
        '                       ██╔══╝  ██╔══██╗██║   ██║██║╚██╔╝██║                          ',
        '                       ██║     ██║  ██║╚██████╔╝██║ ╚═╝ ██║                          ',
        '                       ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝                          ',
        '                                                                    ',
        '                                                           ██╗  ██╗███████╗██╗     ██╗                                    ',
        '                                                           ██║  ██║██╔════╝██║     ██║                                    ',
        '                                                           ███████║█████╗  ██║     ██║                                    ',
        '                                                           ██╔══██║██╔══╝  ██║     ██║                                    ',
        '                                                           ██║  ██║███████╗███████╗███████╗                               ',
        '                                                           ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝                               ',
        '                                                                    ',
        '                    ⸸ FROM THE ABYSS ⸸                             ',
        '                   ⛧ RISE AND CODE ⛧                               ',
        '                                                                    ',
        '',
      }
      
      vim.g.startify_lists = {
        { type = 'files', header = {'   ⸸ RECENT DAMNED FILES ⸸'} },
        { type = 'dir', header = {'   🕯 CURRENT HELLISH DIRECTORY 🕯'} },
        { type = 'sessions', header = {'   ⛧ DARK SESSIONS ⛧'} },
        { type = 'bookmarks', header = {'   ☠ OCCULT BOOKMARKS ☠'} },
      }
      
      vim.g.startify_bookmarks = {
        { c = '~/.config/nvim/init.lua' },
        { z = '~/.zshrc' },
        { p = '~/.config/pywal' },
      }
      
      vim.g.startify_session_dir = '~/.config/nvim/sessions'
      vim.g.startify_session_autoload = 1
      vim.g.startify_session_persistence = 1
      vim.g.startify_change_to_vcs_root = 1
      vim.g.startify_fortune_use_unicode = 1
      
      -- Custom footer with occult symbols
      vim.g.startify_custom_footer = {
        '',
        '    ⸸ May your code be filled with power ⸸',
        '      ⛧ The darkness guides your fingers ⛧',
        '         ☠ HAIL SATAN ☠',
      }
    end,
  },
} 
