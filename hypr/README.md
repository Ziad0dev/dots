# 🔥 Hyprland Configuration - Occult Blood Red Theme

A complete Hyprland setup migrated from i3, preserving your occult aesthetic and workflow while gaining modern Wayland benefits.

## 🎯 Features

- **Exact i3 Keybindings**: All your muscle memory preserved
- **Pywal Integration**: Dynamic theming with your wallpapers  
- **Occult Workspaces**: Your beloved workspace names maintained
- **Scratchpad Support**: Special workspaces for translate/calendar
- **Enhanced Performance**: Native Wayland with smooth animations
- **Modern Tools**: Waybar, rofi-wayland, wl-clipboard integration

## 🚀 Quick Start

```bash
# Navigate to the hyprland directory
cd ~/dots/hypr

# Run the installation script (works on Arch Linux and Ubuntu)
chmod +x install.sh
./install.sh

# For Ubuntu users: See UBUNTU_GUIDE.md for additional details
# Logout and select Hyprland from your display manager
# Or run from TTY: Hyprland
```

## 🐧 Distribution Support

- **Arch Linux**: Full native support with AUR packages
- **Ubuntu 22.04+**: Supported via PPAs and source builds (see `UBUNTU_GUIDE.md`)
- **Other Debian-based**: Should work with manual package installation
- **Fedora/RHEL**: Basic support (may need manual tweaking)

## 📁 File Structure

```
hypr/
├── hyprland.conf          # Main Hyprland configuration
├── install.sh             # Automated installation script  
├── MIGRATION_GUIDE.md     # Detailed migration guide
├── scripts/
│   ├── power-menu.sh      # Power options with rofi
│   ├── random-wallpaper.sh # Random wallpaper + pywal
│   ├── theme-selector.sh  # Interactive theme selection
│   ├── update-colors.sh   # Pywal color integration
│   └── setup-scratchpads.sh # Initialize special workspaces
├── dunstrc               # Notification daemon config
└── rofi-config.rasi      # Rofi launcher styling
```

## ⌨️ Key Features

### Preserved from i3
- `Super+Return` - Terminal
- `Super+D` - App launcher  
- `Super+H/J/K/L` - Vim-like navigation
- `Super+1-9` - Workspace switching
- `Super+T/C` - Translate/Calendar scratchpads
- `Super+Shift+W` - Random wallpaper

### Enhanced for Hyprland
- Smooth animations and transitions
- Better multi-monitor support
- Touch gesture support
- Native Wayland security
- Improved gaming performance

## 🎨 Theming

Your pywal setup works identically:
- Drop wallpapers in `~/Pictures/`
- Use `Super+Shift+W` for random wallpaper
- Colors automatically update all components
- Maintains dark occult aesthetic

## 📋 Dependencies

### Core (Auto-installed)
- hyprland
- waybar (replaces polybar)
- rofi-wayland  
- dunst
- swww (wallpaper daemon)
- kitty
- python-pywal

### Optional Tools
- grim + slurp (screenshots)
- swaylock (screen lock)
- cliphist (clipboard manager)

## 🔧 Customization

Edit `~/.config/hypr/hyprland.conf` for:
- Keybinding modifications
- Animation settings  
- Window rules
- Workspace behavior

## 📚 Documentation

- See `MIGRATION_GUIDE.md` for detailed transition info
- Check [Hyprland Wiki](https://wiki.hyprland.org/) for advanced config
- Your original i3 config remains in `../i3/` for reference

## 🖤 Embrace the Darkness

Your journey from X11 to Wayland is complete. The occult aesthetic lives on with modern performance and security.

*"Evolution through darkness, power through change."* 🔮
