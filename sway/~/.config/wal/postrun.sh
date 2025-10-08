#!/bin/sh

# Apply the color scheme to various programs
# Reload dunst if it's running
if pgrep -x "dunst" > /dev/null; then
    killall dunst
    dunst &
fi

# Update rofi colors
mkdir -p ~/.config/rofi
cat > ~/.config/rofi/occult_theme.rasi << EOF
* {
    background:     #220000;
    background-alt: #350000;
    foreground:     #FFFFFF;
    selected:       #8B0000;
    urgent:         #A30000;
    active:         #AA0000;
    border:         #500000;
}
EOF

# Update kitty terminal colors if used
if [ -d "$HOME/.config/kitty" ]; then
    cat > ~/.config/kitty/colors.conf << EOF
# Occult Blood Red Theme for kitty
foreground #FFFFFF
background #100000
cursor #8B0000
cursor_text_color #000000

# Normal colors
color0 #000000
color1 #8B0000
color2 #500000
color3 #700000
color4 #400000
color5 #600000
color6 #900000
color7 #AAAAAA

# Bright colors
color8 #555555
color9 #A30000
color10 #700000
color11 #900000
color12 #600000
color13 #800000
color14 #AA0000
color15 #FFFFFF
EOF
fi

# Apply to firefox if theme extension is installed
if [ -d "$HOME/.mozilla" ]; then
    mkdir -p ~/.mozilla/firefox/chrome
    echo '@import url("occult_blood.css")' > ~/.mozilla/firefox/chrome/userChrome.css
    cat > ~/.mozilla/firefox/chrome/occult_blood.css << EOF
:root {
  --occult-background: #220000;
  --occult-foreground: #FFFFFF;
  --occult-highlight: #8B0000;
  --occult-secondary: #500000;
}

#browser {
  background-color: var(--occult-background) !important;
  color: var(--occult-foreground) !important;
}

.tab-background[selected="true"] {
  background-color: var(--occult-highlight) !important;
}
EOF
fi

echo "Occult Blood Red theme applied to system" 