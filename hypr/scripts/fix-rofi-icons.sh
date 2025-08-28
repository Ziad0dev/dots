#!/bin/bash
# Rofi Icon Troubleshooting Script for Hyprland
# Fixes common icon display issues

echo "🔍 ROFI ICON TROUBLESHOOTING"
echo "============================"

# Check if rofi is installed
if ! command -v rofi &> /dev/null; then
    echo "❌ Rofi is not installed!"
    echo "Installing rofi..."
    if command -v pacman &> /dev/null; then
        sudo pacman -S rofi
    elif command -v apt &> /dev/null; then
        sudo apt install rofi
    fi
    exit 1
fi

echo "✅ Rofi version: $(rofi -version | head -1)"

# Check icon theme
echo ""
echo "🎨 Checking icon themes..."
ICON_THEMES=("/usr/share/icons" "$HOME/.local/share/icons" "$HOME/.icons")
FOUND_THEMES=()

for dir in "${ICON_THEMES[@]}"; do
    if [ -d "$dir" ]; then
        for theme in "$dir"/*; do
            if [ -d "$theme" ]; then
                FOUND_THEMES+=("$(basename "$theme")")
            fi
        done
    fi
done

if [ ${#FOUND_THEMES[@]} -eq 0 ]; then
    echo "❌ No icon themes found!"
    echo "Installing Papirus icon theme..."
    if command -v pacman &> /dev/null; then
        sudo pacman -S papirus-icon-theme
    elif command -v apt &> /dev/null; then
        sudo apt install papirus-icon-theme
    fi
else
    echo "✅ Found icon themes: ${FOUND_THEMES[*]}"
fi

# Check if Papirus is available
if [[ " ${FOUND_THEMES[*]} " =~ " Papirus " ]]; then
    echo "✅ Papirus theme is available"
else
    echo "⚠️  Papirus theme not found, installing..."
    if command -v pacman &> /dev/null; then
        sudo pacman -S papirus-icon-theme
    elif command -v apt &> /dev/null; then
        sudo apt install papirus-icon-theme
    fi
fi

# Check rofi configuration
echo ""
echo "⚙️  Checking rofi configuration..."
ROFI_CONFIG="$HOME/.config/rofi/config.rasi"

if [ -f "$ROFI_CONFIG" ]; then
    echo "✅ Rofi config found: $ROFI_CONFIG"
    
    # Check for show-icons setting
    if grep -q "show-icons.*true" "$ROFI_CONFIG"; then
        echo "✅ show-icons is enabled"
    else
        echo "❌ show-icons is NOT enabled"
        echo "Adding show-icons: true to configuration..."
        
        # Create backup
        cp "$ROFI_CONFIG" "$ROFI_CONFIG.backup"
        
        # Add show-icons if not present
        if grep -q "configuration" "$ROFI_CONFIG"; then
            sed -i '/configuration {/a\    show-icons: true;' "$ROFI_CONFIG"
        else
            echo -e "configuration {\n    show-icons: true;\n}" > "$ROFI_CONFIG.new"
            cat "$ROFI_CONFIG" >> "$ROFI_CONFIG.new"
            mv "$ROFI_CONFIG.new" "$ROFI_CONFIG"
        fi
    fi
    
    # Check for icon-theme setting
    if grep -q "icon-theme" "$ROFI_CONFIG"; then
        CURRENT_THEME=$(grep "icon-theme" "$ROFI_CONFIG" | sed 's/.*: *"\([^"]*\)".*/\1/')
        echo "✅ Icon theme set to: $CURRENT_THEME"
    else
        echo "⚠️  No icon-theme specified, adding Papirus..."
        sed -i '/show-icons/a\    icon-theme: "Papirus";' "$ROFI_CONFIG"
    fi
    
else
    echo "❌ Rofi config not found!"
    echo "Creating basic rofi configuration with icons..."
    mkdir -p ~/.config/rofi
    cat > "$ROFI_CONFIG" << 'EOF'
configuration {
    modi: "drun,run";
    show-icons: true;
    icon-theme: "Papirus";
    drun-display-format: "{icon} {name}";
    font: "JetBrainsMono Nerd Font 10";
}
EOF
fi

# Test desktop entries
echo ""
echo "📱 Checking .desktop files..."
DESKTOP_DIRS=("/usr/share/applications" "$HOME/.local/share/applications")
DESKTOP_COUNT=0

for dir in "${DESKTOP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        count=$(find "$dir" -name "*.desktop" | wc -l)
        DESKTOP_COUNT=$((DESKTOP_COUNT + count))
        echo "Found $count .desktop files in $dir"
    fi
done

if [ $DESKTOP_COUNT -eq 0 ]; then
    echo "❌ No .desktop files found!"
    echo "This might be why no applications show up with icons."
else
    echo "✅ Total .desktop files: $DESKTOP_COUNT"
fi

# Check environment variables
echo ""
echo "🌍 Checking environment variables..."
if [ -n "$XDG_DATA_DIRS" ]; then
    echo "✅ XDG_DATA_DIRS: $XDG_DATA_DIRS"
else
    echo "⚠️  XDG_DATA_DIRS not set"
    export XDG_DATA_DIRS="/usr/local/share:/usr/share"
fi

# Test rofi with debugging
echo ""
echo "🧪 Testing rofi with debug output..."
echo "Running: rofi -show drun -show-icons"
echo "(This will show any error messages)"
echo ""

# Create a simple test
timeout 5s rofi -show drun -dump 2>&1 | head -10

echo ""
echo "💡 SOLUTIONS:"
echo "============="
echo "1. Make sure rofi is the Wayland version (not X11-only)"
echo "2. Install icon themes: sudo apt install papirus-icon-theme"
echo "3. Refresh icon cache: sudo gtk-update-icon-cache -f /usr/share/icons/*"
echo "4. Check rofi config has: show-icons: true; and icon-theme: \"Papirus\";"
echo "5. For Hyprland, use our custom theme: rofi -show drun -theme ~/.config/hypr/rofi-hyprland.rasi"
echo ""
echo "🔧 To fix immediately:"
echo "cp ~/dots/hypr/rofi-hyprland.rasi ~/.config/rofi/config.rasi"
echo "rofi -show drun -theme ~/.config/rofi/config.rasi"
