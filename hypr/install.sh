#!/bin/bash
# Hyprland Installation Script
# Installs all necessary packages for your Hyprland setup

echo "🔥 HYPRLAND SETUP - OCCULT MIGRATION FROM i3 🔥"
echo "================================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Don't run this script as root!" 
   exit 1
fi

# Detect package manager
if command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    INSTALL_CMD="sudo pacman -S --needed"
    AUR_HELPER=""
    
    # Check for AUR helper
    if command -v yay &> /dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &> /dev/null; then
        AUR_HELPER="paru"
    fi
    
elif command -v apt &> /dev/null; then
    PKG_MANAGER="apt"
    INSTALL_CMD="sudo apt install"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install"
else
    echo "❌ Unsupported package manager. This script supports pacman, apt, and dnf."
    exit 1
fi

echo "📦 Detected package manager: $PKG_MANAGER"
if [[ -n "$AUR_HELPER" ]]; then
    echo "🏗️  AUR helper found: $AUR_HELPER"
fi

# Core Hyprland packages
CORE_PACKAGES=(
    "hyprland"
    "waybar"
    "rofi-wayland"
    "dunst"
    "swww"
    "swaylock"
    "grim"
    "slurp"
    "wl-clipboard"
    "cliphist"
    "kitty"
    "pipewire"
    "pipewire-pulse"
    "wireplumber"
    "polkit-gnome"
    "xdg-desktop-portal-hyprland"
    "xdg-desktop-portal-gtk"
    "python-pywal"
    "notify-send"
)

# Optional but recommended packages
OPTIONAL_PACKAGES=(
    "firefox"
    "thunar"
    "pavucontrol"
    "network-manager-applet"
    "blueman"
    "udiskie"
    "translate-shell"
    "khal"
)

# Function to install packages
install_packages() {
    local packages=("$@")
    
    case $PKG_MANAGER in
        "pacman")
            $INSTALL_CMD "${packages[@]}"
            ;;
        "apt")
            # Update package lists first
            sudo apt update
            
            # Some package names are different on Ubuntu/Debian
            local apt_packages=()
            for pkg in "${packages[@]}"; do
                case $pkg in
                    "hyprland") 
                        # Hyprland needs to be built from source or PPA on Ubuntu
                        echo "⚠️  Hyprland will be installed via PPA or built from source"
                        apt_packages+=("") # Handle separately
                        ;;
                    "rofi-wayland") 
                        # Use regular rofi with wayland support
                        apt_packages+=("rofi")
                        ;;
                    "python-pywal") apt_packages+=("python3-pywal") ;;
                    "pipewire-pulse") apt_packages+=("pipewire-pulse") ;;
                    "polkit-gnome") apt_packages+=("policykit-1-gnome") ;;
                    "xdg-desktop-portal-hyprland") 
                        apt_packages+=("") # Will be built with Hyprland
                        ;;
                    "swww") 
                        echo "⚠️  swww will be installed via cargo or built from source"
                        apt_packages+=("") # Handle separately
                        ;;
                    "cliphist")
                        echo "⚠️  cliphist will be installed via go or built from source"  
                        apt_packages+=("") # Handle separately
                        ;;
                    "waybar") apt_packages+=("waybar") ;;
                    "notify-send") apt_packages+=("libnotify-bin") ;;
                    "network-manager-applet") apt_packages+=("network-manager-gnome") ;;
                    "translate-shell") apt_packages+=("translate-shell") ;;
                    "khal") apt_packages+=("khal") ;;
                    "") ;; # Skip empty entries
                    *) apt_packages+=("$pkg") ;;
                esac
            done
            
            # Filter out empty entries
            apt_packages=($(printf '%s\n' "${apt_packages[@]}" | grep -v '^$'))
            
            if [ ${#apt_packages[@]} -gt 0 ]; then
                $INSTALL_CMD "${apt_packages[@]}"
            fi
            ;;
        "dnf")
            $INSTALL_CMD "${packages[@]}"
            ;;
    esac
}

echo ""
echo "🎯 Installing core Hyprland packages..."
install_packages "${CORE_PACKAGES[@]}"

echo ""
echo "📋 Installing optional packages..."
install_packages "${OPTIONAL_PACKAGES[@]}"

# Ubuntu-specific installations
if [[ "$PKG_MANAGER" == "apt" ]]; then
    echo ""
    echo "🔧 Ubuntu-specific setup..."
    
    # Install Hyprland
    echo "📦 Installing Hyprland..."
    if ! command -v hyprland &> /dev/null; then
        echo "Adding Hyprland PPA..."
        sudo add-apt-repository ppa:hyprwm/hyprland -y
        sudo apt update
        sudo apt install hyprland -y
        
        # If PPA fails, offer to build from source
        if ! command -v hyprland &> /dev/null; then
            echo "⚠️  PPA installation failed. Would you like to build from source? (y/N)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                echo "📋 Building Hyprland from source requires many dependencies..."
                echo "Please follow: https://wiki.hyprland.org/Getting-Started/Installation/#manual-manual-build"
                echo "This script will continue with other components."
            fi
        fi
    fi
    
    # Install swww (wallpaper daemon)
    echo "📦 Installing swww..."
    if ! command -v swww &> /dev/null; then
        if command -v cargo &> /dev/null; then
            cargo install swww
        else
            echo "📋 Installing Rust for swww..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source ~/.cargo/env
            cargo install swww
        fi
    fi
    
    # Install cliphist (clipboard manager)
    echo "📦 Installing cliphist..."
    if ! command -v cliphist &> /dev/null; then
        if command -v go &> /dev/null; then
            go install go.senan.xyz/cliphist@latest
        else
            echo "📋 Installing Go for cliphist..."
            sudo apt install golang-go -y
            go install go.senan.xyz/cliphist@latest
            # Add Go bin to PATH if not already there
            if ! echo "$PATH" | grep -q "$HOME/go/bin"; then
                echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
                echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.zshrc
                export PATH=$PATH:$HOME/go/bin
            fi
        fi
    fi
    
    # Install xdg-desktop-portal-hyprland
    echo "📦 Installing xdg-desktop-portal-hyprland..."
    if ! dpkg -l | grep -q xdg-desktop-portal-hyprland; then
        # This usually gets built with Hyprland or is available in newer Ubuntu versions
        sudo apt install xdg-desktop-portal-hyprland -y 2>/dev/null || {
            echo "⚠️  xdg-desktop-portal-hyprland not available in repos"
            echo "It may have been installed with Hyprland or needs manual building"
        }
    fi
    
    # Install icon themes and fonts for rofi icons
    echo "📦 Installing icon themes and fonts..."
    sudo apt install papirus-icon-theme hicolor-icon-theme -y
    sudo apt install fonts-jetbrains-mono fonts-noto fonts-noto-color-emoji -y
    sudo fc-cache -fv
    
    echo "✅ Ubuntu-specific setup complete"
fi

# AUR packages (Arch Linux only)
if [[ "$PKG_MANAGER" == "pacman" && -n "$AUR_HELPER" ]]; then
    echo ""
    echo "🏗️  Installing AUR packages..."
    
    AUR_PACKAGES=(
        "hyprpicker"
        "wlogout"
    )
    
    $AUR_HELPER -S --needed "${AUR_PACKAGES[@]}"
fi

echo ""
echo "📁 Setting up configuration symlinks..."

# Create .config directory if it doesn't exist
mkdir -p ~/.config

# Backup existing configs
backup_config() {
    local config_name=$1
    if [[ -d ~/.config/$config_name ]]; then
        echo "📦 Backing up existing $config_name config to $config_name.backup"
        mv ~/.config/$config_name ~/.config/$config_name.backup
    fi
}

# Backup and symlink configs
backup_config "hypr"
backup_config "waybar"
backup_config "dunst"

# Create symlinks
ln -sf ~/dots/hypr ~/.config/hypr
ln -sf ~/dots/waybar ~/.config/waybar
ln -sf ~/dots/hypr/dunstrc ~/.config/dunst/dunstrc

# Copy rofi config to existing rofi directory
mkdir -p ~/.config/rofi
cp ~/dots/hypr/rofi-hyprland.rasi ~/.config/rofi/hyprland.rasi
cp ~/dots/rofi/ab67616d0000b273d62a6267448745ca64db99ea.jpeg ~/.config/rofi/
ln -sf ~/.config/rofi/hyprland.rasi ~/.config/rofi/config.rasi

echo ""
echo "🎨 Setting up pywal integration..."

# Create pywal cache directory
mkdir -p ~/.cache/wal

# Run initial color generation if wallpaper exists
if [[ -f ~/Pictures/wp15589380.png ]]; then
    echo "🖼️  Generating initial color scheme..."
    wal -i ~/Pictures/wp15589380.png -n
    ~/.config/hypr/scripts/update-colors.sh
fi

echo ""
echo "🔧 Setting up systemd services..."

# Enable pipewire services
systemctl --user enable pipewire pipewire-pulse wireplumber

echo ""
echo "✅ Installation complete!"
echo ""
echo "🚀 NEXT STEPS:"
echo "1. Logout and select Hyprland from your display manager"
echo "2. Or run 'Hyprland' from a TTY"
echo "3. Use Super+D to open the application launcher"
echo "4. Use Super+Shift+W for random wallpaper"
echo "5. Use Super+Shift+T for theme selector"
echo ""
echo "📚 KEYBINDINGS (same as your i3 setup):"
echo "  Super+Return       - Terminal (kitty)"
echo "  Super+D            - App launcher (rofi)"
echo "  Super+Shift+Q      - Kill window"
echo "  Super+F            - Fullscreen"
echo "  Super+H/J/K/L      - Focus movement (vim-like)"
echo "  Super+Shift+H/J/K/L - Move windows"
echo "  Super+1-9          - Switch workspace"
echo "  Super+Shift+1-9    - Move to workspace"
echo "  Super+T            - Toggle translate scratchpad"
echo "  Super+C            - Toggle calendar scratchpad"
echo "  Super+Shift+P      - Power menu"
echo ""
echo "🔧 CONFIGURATION LOCATIONS:"
echo "  Hyprland: ~/.config/hypr/hyprland.conf"
echo "  Waybar:   ~/.config/waybar/"
echo "  Scripts:  ~/.config/hypr/scripts/"
echo ""
echo "🎨 Your pywal themes and wallpapers will work the same way!"
echo "   Wallpaper directory: ~/Pictures/"
echo ""
echo "May the occult powers guide your new Wayland journey! 🖤"
