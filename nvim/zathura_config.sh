#!/bin/bash

# ⸸ Satanic Zathura Configuration Script ⸸
echo "⸸ Setting up Zathura configuration..."

# Create zathura config directory
mkdir -p ~/.config/zathura

# Create zathura configuration with dark theme
cat > ~/.config/zathura/zathurarc << 'EOF'
# ⸸ Satanic Zathura Configuration ⸸

# Dark theme colors
set default-bg              "#1e1e1e"
set default-fg              "#f8f8f2"
set statusbar-fg             "#f8f8f2"
set statusbar-bg             "#44475a"
set inputbar-bg              "#282a36"
set inputbar-fg              "#f8f8f2"
set notification-bg          "#282a36"
set notification-fg          "#f8f8f2"
set notification-error-bg    "#ff5555"
set notification-error-fg    "#f8f8f2"
set notification-warning-bg  "#ffb86c"
set notification-warning-fg  "#282a36"
set highlight-color          "#ffb86c"
set highlight-active-color   "#ff79c6"
set completion-bg            "#282a36"
set completion-fg            "#6272a4"
set completion-group-bg      "#282a36"
set completion-group-fg      "#50fa7b"
set completion-highlight-bg  "#44475a"
set completion-highlight-fg  "#f8f8f2"
set index-bg                 "#282a36"
set index-fg                 "#f8f8f2"
set index-active-bg          "#44475a"
set index-active-fg          "#f8f8f2"

# Recolor mode settings
set recolor                  true
set recolor-lightcolor       "#282a36"
set recolor-darkcolor        "#f8f8f2"
set recolor-reverse-video    true
set recolor-keephue          true

# Performance settings
set render-loading           true
set scroll-step              50
set zoom-min                 10
set zoom-max                 1000
set zoom-step                10

# Interface settings
set statusbar-h-padding      0
set statusbar-v-padding      0
set page-padding             1
set selection-clipboard      clipboard

# Key bindings
map u scroll half-up
map d scroll half-down
map D toggle_page_mode
map r reload
map R rotate
map K zoom in
map J zoom out
map i recolor
map p print
EOF

echo "☠ Zathura configuration created!"
echo "Features:"
echo "  ✓ Dark theme matching your satanic setup"
echo "  ✓ Better scrolling and zoom controls"
echo "  ✓ Improved keybindings (u/d for half-page scroll)"
echo "  ✓ Auto-recolor for better readability" 