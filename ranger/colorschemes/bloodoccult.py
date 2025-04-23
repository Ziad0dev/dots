# Blood Red Occult theme for ranger file manager
# Based on the default colorscheme with occult and blood-themed colors

from __future__ import (absolute_import, division, print_function)

from ranger.gui.colorscheme import ColorScheme
from ranger.gui.color import (
    black, blue, cyan, green, magenta, red, white, yellow, default,
    normal, bold, reverse, dim, BRIGHT,
    default_colors,
)


class BloodOccult(ColorScheme):
    progress_bar_color = red

    # Define custom colors for the occult theme
    blood_red = 124  # Dark red
    crimson = 160    # Bright blood red
    dark_crimson = 52  # Very dark red
    bone = 223       # Pale yellow/bone color
    purple_dark = 54  # Dark purple
    violet = 91      # Violet for mystical elements

    def use(self, context):
        fg, bg, attr = default_colors

        if context.reset:
            return default_colors

        elif context.in_browser:
            if context.selected:
                attr = reverse
            else:
                attr = normal
            
            if context.empty or context.error:
                fg = self.crimson
            if context.border:
                fg = self.dark_crimson
            if context.media:
                if context.image:
                    fg = self.violet
                else:
                    fg = magenta
            if context.container:
                fg = self.crimson
            if context.directory:
                attr |= bold
                fg = self.blood_red
            elif context.executable and not \
                    any((context.media, context.container,
                         context.fifo, context.socket)):
                attr |= bold
                fg = self.crimson
            if context.socket:
                attr |= bold
                fg = self.purple_dark
            if context.fifo or context.device:
                fg = self.bone
                if context.device:
                    attr |= bold
            if context.link:
                fg = self.violet if context.good else self.crimson
            if context.tag_marker and not context.selected:
                attr |= bold
                fg = self.blood_red
            if not context.selected and (context.cut or context.copied):
                attr |= bold
                fg = black
                bg = self.blood_red
            if context.main_column:
                if context.selected:
                    attr |= bold
                if context.marked:
                    attr |= bold
                    fg = self.bone
                    bg = self.dark_crimson
            if context.badinfo:
                fg = self.crimson

            if context.inactive_pane:
                fg = self.dark_crimson

        elif context.in_titlebar:
            if context.hostname:
                fg = self.crimson if context.bad else self.bone
            elif context.directory:
                fg = self.blood_red
            elif context.tab:
                if context.good:
                    fg = self.bone
                    bg = self.dark_crimson
            elif context.link:
                fg = self.violet
            attr |= bold

        elif context.in_statusbar:
            if context.permissions:
                if context.good:
                    fg = self.bone
                elif context.bad:
                    fg = self.crimson
            if context.marked:
                attr |= bold | reverse
                fg = self.blood_red
            if context.frozen:
                attr |= bold | reverse
                fg = self.violet
            if context.message:
                if context.bad:
                    attr |= bold
                    fg = self.crimson
            if context.loaded:
                bg = self.blood_red
            if context.vcsinfo:
                fg = self.purple_dark
                attr &= ~bold
            if context.vcscommit:
                fg = self.bone
                attr &= ~bold
            if context.vcsdate:
                fg = self.violet
                attr &= ~bold

        if context.text:
            if context.highlight:
                attr |= reverse

        if context.in_taskview:
            if context.title:
                fg = self.blood_red

            if context.selected:
                attr |= reverse

            if context.loaded:
                if context.selected:
                    fg = self.progress_bar_color
                else:
                    bg = self.progress_bar_color

        if context.vcsfile and not context.selected:
            attr &= ~bold
            if context.vcsconflict:
                fg = self.crimson
            elif context.vcsuntracked:
                fg = self.violet
            elif context.vcschanged:
                fg = self.blood_red
            elif context.vcsunknown:
                fg = self.crimson
            elif context.vcsstaged:
                fg = self.bone
            elif context.vcssync:
                fg = self.bone
            elif context.vcsignored:
                fg = default

        elif context.vcsremote and not context.selected:
            attr &= ~bold
            if context.vcssync or context.vcsnone:
                fg = self.bone
            elif context.vcsbehind:
                fg = self.crimson
            elif context.vcsahead:
                fg = self.purple_dark
            elif context.vcsdiverged:
                fg = magenta
            elif context.vcsunknown:
                fg = self.crimson

        return fg, bg, attr 