# Pywal Ranger Colorscheme
# Auto-generated from wallpaper colors

from ranger.gui.colorscheme import ColorScheme
from ranger.gui.color import *

class pywal_dynamic(ColorScheme):
    progress_bar_color = {color6_num}
    
    def use(self, context):
        fg, bg, attr = default_colors
        
        if context.reset:
            return default_colors
            
        elif context.in_browser:
            if context.selected:
                attr = reverse
                if context.empty or context.error:
                    bg = {color9_num}  # red for errors
                    fg = {color0_num}
                if context.border:
                    fg = {color6_num}  # accent color
                if context.media:
                    if context.image:
                        fg = 19  # yellow for images
                    else:
                        fg = 21  # magenta for media
                if context.container:
                    fg = 17  # red for archives
                if context.directory:
                    attr |= bold
                    fg = 20  # blue for directories
                elif context.executable and not \
                        any((context.media, context.container,
                            context.fifo, context.socket)):
                    attr |= bold
                    fg = 18  # green for executables
                if context.socket:
                    fg = 21  # magenta
                    attr |= bold
                if context.fifo or context.device:
                    fg = 19  # yellow
                    if context.device:
                        attr |= bold
                if context.link:
                    fg = 22  # cyan for links
                    if context.bad:
                        bg = 25
                if context.tag_marker and not context.selected:
                    attr |= bold
                    if fg in (23, 31):
                        fg = 17  # red for tags
                    else:
                        fg = 25
                if not context.selected and (context.cut or context.copied):
                    fg = 24  # dim for cut/copied
                    bg = 16
                if context.main_column:
                    if context.selected:
                        attr |= bold
                    if context.marked:
                        attr |= bold
                        fg = 19  # yellow for marked
                if context.badinfo:
                    if attr & reverse:
                        bg = 25
                    else:
                        fg = 25
                        
        elif context.in_titlebar:
            attr |= bold
            if context.hostname:
                fg = 17  # red for hostname
            elif context.directory:
                fg = 20  # blue for directory
            elif context.tab:
                if context.good:
                    bg = 18  # green bg for active tab
            elif context.link:
                fg = 22  # cyan for links
                
        elif context.in_statusbar:
            if context.permissions:
                if context.good:
                    fg = 18  # green for good permissions
                elif context.bad:
                    fg = 17  # red for bad permissions
            if context.marked:
                attr |= bold | reverse
                fg = 19  # yellow for marked
            if context.message:
                if context.bad:
                    attr |= bold
                    fg = 25  # bright red for error messages
            if context.loaded:
                bg = self.progress_bar_color
                
        if context.text:
            if context.highlight:
                attr |= reverse
                
        if context.in_taskview:
            if context.title:
                fg = 20  # blue for task titles
            if context.selected:
                attr |= reverse
                
        if context.vcsinfo:
            fg = 22  # cyan for version control info
            attr &= ~bold
        elif context.vcscommit:
            fg = 19  # yellow for commits
            attr &= ~bold
            
        return fg, bg, attr
