# 🔥 HYPRLAND MIGRATION GUIDE 🔥
## From i3 to Hyprland - Occult Blood Red Edition

Welcome to your Hyprland upgrade! This guide will help you seamlessly transition from your i3 setup to Hyprland while preserving all your beloved occult aesthetics and functionality.

## 📋 What's Been Preserved

### ✅ Exact Same Functionality
- **Workspace Names**: Your occult workspace names (1:Main, 2:IDE, 3:Hell, 4:Satan, 5:Void, 6:Curse, 7:Doom, 8:Music, 9:Discord)
- **Keybindings**: All your i3 keybindings work exactly the same
- **Scratchpads**: Translate and calendar scratchpads (Super+T, Super+C)
- **Application Assignments**: Same apps go to same workspaces
- **Pywal Integration**: Dynamic color theming with your wallpapers
- **Window Rules**: Floating, opacity, and sizing rules preserved

### ✅ Enhanced Features
- **Better Animations**: Smooth transitions and window effects
- **Improved Tearing**: Better gaming/video performance
- **Gesture Support**: Touchpad gestures for laptop users
- **Better Scaling**: HiDPI support out of the box
- **Native Wayland**: No more X11 quirks, better security

## 🚀 Installation

```bash
cd ~/dots/hypr
chmod +x install.sh
./install.sh
```

The installation script will:
1. Install all necessary packages
2. Backup your existing configs
3. Set up symlinks to your dotfiles
4. Configure pywal integration
5. Enable required services

## 🎮 Key Differences from i3

### Window Manager → Compositor
- Hyprland is a **compositor**, not just a window manager
- Built-in effects, no need for separate compositor (picom replacement)
- Native Wayland, so some X11-specific tools won't work

### Equivalent Commands
| i3 | Hyprland |
|---|---|
| `i3-msg` | `hyprctl` |
| `i3lock` | `swaylock` |
| `feh` | `swww` |
| `maim` | `grim + slurp` |
| `xclip` | `wl-clipboard` |

### New Capabilities
- **Special Workspaces**: Your scratchpads are now "special workspaces"
- **Layer Management**: Better notification and overlay handling
- **Touch Gestures**: 3-finger swipe between workspaces
- **Per-Monitor Workspaces**: Better multi-monitor support

## 🔧 Configuration Structure

```
~/.config/hypr/
├── hyprland.conf          # Main config (replaces i3/config)
├── scripts/
│   ├── power-menu.sh      # Power menu with rofi
│   ├── random-wallpaper.sh # Wallpaper + pywal integration
│   ├── theme-selector.sh  # Theme selection menu
│   ├── update-colors.sh   # Pywal color updater
│   └── setup-scratchpads.sh # Initialize scratchpads
├── dunstrc               # Notification config
└── rofi-config.rasi      # Rofi styling
```

## 🎨 Theming & Colors

Your pywal integration works exactly the same:
- Wallpapers in `~/Pictures/` 
- `Super+Shift+W` for random wallpaper
- `Super+Shift+T` for theme selector
- All colors automatically update Hyprland, Waybar, and Rofi

## 📊 Waybar (Polybar Replacement)

Waybar replaces Polybar with:
- Same information display
- Native Wayland support  
- JSON configuration
- CSS styling with pywal colors
- Better system integration

## ⌨️ Complete Keybinding Reference

### Core Navigation (Unchanged from i3)
- `Super+Return` - Terminal (kitty)
- `Super+D` - App launcher (rofi)
- `Super+Shift+Q` - Kill window
- `Super+F` - Fullscreen
- `Super+H/J/K/L` - Focus movement (vim-like)
- `Super+Shift+H/J/K/L` - Move windows

### Workspaces (Unchanged)
- `Super+1-9` - Switch workspace
- `Super+Shift+1-9` - Move to workspace
- `Super+Ctrl+B/P/M/D` - Quick access (Browser/Programming/Music/Discord)

### Scratchpads (Special Workspaces)
- `Super+T` - Toggle translate scratchpad
- `Super+C` - Toggle calendar scratchpad

### New Hyprland Features
- `Super+Ctrl+H/J/K/L` - Resize windows
- Mouse gestures on touchpad
- `Super+Shift+P` - Power menu

### Media & System (Unchanged)
- Volume keys work the same
- Screenshot keys work the same
- `Super+Shift+W/T` - Wallpaper/theme controls

## 🔄 Migration Checklist

### Before Migration
- [ ] Backup important data
- [ ] Note any custom i3 scripts you use
- [ ] Save current wallpaper setup

### After Installation
- [ ] Run the install script
- [ ] Logout and select Hyprland in display manager
- [ ] Test all keybindings
- [ ] Verify scratchpads work (Super+T, Super+C)
- [ ] Test wallpaper changing (Super+Shift+W)
- [ ] Check application assignments
- [ ] Verify audio/media controls

### Troubleshooting
- If waybar doesn't start: Check `journalctl --user -u waybar`
- If colors don't apply: Run `~/.config/hypr/scripts/update-colors.sh`
- If scratchpads don't work: Run `~/.config/hypr/scripts/setup-scratchpads.sh`
- For any crashes: Check `hyprctl logs`

## 🛠️ Customization

### Adding New Keybindings
Edit `~/.config/hypr/hyprland.conf`, add:
```
bind = SUPER, KEY, exec, command
```

### Modifying Animations
In `hyprland.conf`, edit the `animations` section:
```
animation = windows, 1, 4, myBezier
```

### Workspace Rules
Add new workspace assignments:
```
windowrule = workspace 2, ^(your-app)$
```

## 🎯 Performance Tips

### Gaming
- Animations automatically disabled during games
- Tearing prevention for smooth gameplay
- Use `env = WLR_DRM_NO_ATOMIC,1` if needed

### Battery Life
- Reduce animation duration
- Lower blur passes
- Use `misc { vfr = true }`

## 📚 Resources

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Waybar Documentation](https://github.com/Alexays/Waybar/wiki)
- Your dotfiles: `~/dots/hypr/`

## 🖤 Occult Theme Preserved

All your dark aesthetic elements are maintained:
- Blood red accents
- Dark backgrounds
- Occult workspace names
- Gothic terminal prompts
- Pywal dark themes

Your journey from the depths of i3 to the ethereal realm of Hyprland is complete! 

*"From the ancient X11 rituals to the modern Wayland incantations, the darkness adapts and evolves."* 🔮

---

**Enjoy your enhanced Wayland experience while keeping the soul of your original setup! 🖤**
