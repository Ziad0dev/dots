#!/bin/bash

# =============================================================================
#  Fedora Dotfiles Installer
#  Author: Ziad0dev
#  Repository: https://github.com/Ziad0dev/dots
# =============================================================================

set -e

# --- Configuration ---
LOG_FILE="install.log"
BACKUP_DIR="$HOME/.config/backup_$(date +%Y%m%d_%H%M%S)"
REPO_URL="https://github.com/Ziad0dev/dots.git"
TARGET_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

# --- Colors & Formatting ---
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Helper Functions ---

banner() {
    clear
    echo -e "${CYAN}"
    echo "███████╗███████╗██████╗  ██████╗ ██████╗  █████╗ "
    echo "██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗"
    echo "█████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║"
    echo "██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║"
    echo "██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║"
    echo "╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${BOLD}Dotfiles Installer for Fedora Linux${NC}"
    echo -e "-----------------------------------"
}

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_sudo() {
    if [ "$EUID" -eq 0 ]; then
        error "Please do not run this script as root (do not use sudo ./install.sh)."
        error "Run it as your normal user: ./install.sh"
        error "The script will ask for your sudo password when needed."
        exit 1
    fi

    # Refresh sudo timestamp
    sudo -v
}

# --- Main Script ---

banner
check_sudo

# Pre-check: Install Git if missing (needed for cloning)
if ! command -v git &> /dev/null; then
    log "Git not found. Installing git..."
    sudo dnf install -y git
fi

# 0. Setup Dotfiles Repository
log "Setting up dotfiles repository..."

CURRENT_DIR=$(pwd)

# Logic to determine if we should use the current directory or clone to TARGET_DIR
# We use TARGET_DIR if:
# 1. We are running from ~/.config (to avoid self-referential loops)
# 2. We are NOT in a git repository
if [ "$CURRENT_DIR" == "$CONFIG_DIR" ]; then
    log "Running from .config directory. Will clone/use repo at $TARGET_DIR."
    USE_TARGET=true
elif [ -d ".git" ] && [ -f "install.sh" ]; then
    log "Running from inside the repository."
    DOTFILES_DIR="$CURRENT_DIR"
    USE_TARGET=false
else
    USE_TARGET=true
fi

if [ "$USE_TARGET" = true ]; then
    if [ -d "$TARGET_DIR" ]; then
        log "Dotfiles directory exists at $TARGET_DIR. Updating..."
        git -C "$TARGET_DIR" pull
    else
        log "Cloning dotfiles repository to $TARGET_DIR..."
        git clone "$REPO_URL" "$TARGET_DIR"
    fi
    DOTFILES_DIR="$TARGET_DIR"
fi

log "Using dotfiles from: $DOTFILES_DIR"

# 1. System Check
if ! grep -q "Fedora" /etc/os-release; then
    error "This script is intended for Fedora Linux."
    exit 1
fi

log "Detected Fedora Linux. Proceeding..."

# 2. Setup Repositories
log "Setting up repositories..."

# VS Code
if ! rpm -q code &> /dev/null; then
    log "Adding VS Code repository..."
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
fi

# RPM Fusion (Needed for OBS, FFmpeg, Codecs)
#log "Enabling RPM Fusion repositories..."
#sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
# Copr Repositories
log "Enabling Copr repositories..."
sudo dnf copr enable -y solopasha/hyprland
sudo dnf copr enable -y swayfx/swayfx
sudo dnf copr enable -y pgdev/ghostty
sudo dnf copr enable -y varlad/yazi
sudo dnf copr enable -y atim/lazygit
sudo dnf copr enable -y sneexy/zen-browser
sudo dnf copr enable -y codifryed/CoolerControl

# Refresh DNF Cache
log "Refreshing package cache..."
sudo dnf makecache

# 3. Install Packages
log "Updating system and installing packages..."
sudo dnf update -y

# Check for Sway/SwayFX situation
SWAY_PKG=""
if rpm -q sway &> /dev/null; then
    log "Sway is already installed. Skipping SwayFX installation to avoid conflicts."
else
    log "Sway not found. Adding SwayFX to installation list..."
    SWAY_PKG="swayfx"
fi

PACKAGES=(
    # --- Core ---
    git
    curl
    wget
    zsh
    jq
    unzip

    # --- Window Managers & Wayland ---
    hyprland
    waybar
    rofi-wayland
    dunst
    picom
    swaybg
    hyprpaper
    hyprlock
    hypridle
    wl-clipboard
    clipman
    grim
    slurp

    # --- Terminals ---
    ghostty

    # --- Browsers & Media ---
    zen-browser
    obs-studio
    ffmpeg
    # --- Editors ---
    neovim
    code

    # --- File Managers ---
    thunar
    ranger
    yazi
    broot

    # --- Development Tools ---
    gcc
    gcc-c++
    make
    cmake
    automake
    nodejs
    npm
    python3-pip
    pipx
    golang
    rust
    cargo
    lazygit
    ghidra
    coolercontrol

    # --- Containerization ---
    podman
    podman-compose

    # --- System Tools ---
    gammastep
    flameshot
    pavucontrol
    lxpolkit
    fzf
    ripgrep
    fd-find
    bat
    eza
    htop
    btop
    pipx

    # --- Theming ---
    # python3-pywal # Installed via pip below

    # --- Fonts ---
    # We install Nerd Fonts manually below
    fontawesome-fonts
    nerdfonts

)

sudo dnf install -y --allowerasing --skip-broken "${PACKAGES[@]}"

# Pywal Setup
if ! command -v wal &> /dev/null; then
    log "Installing Pywal via pipx..."
    pipx install pywal
    pipx ensurepath
fi

log "Setting up Flatpak and installing Spotify..."
sudo dnf install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install -y flathub com.spotify.Client

# 4. Install External Tools

# Spicetify
if ! command -v spicetify &> /dev/null; then
    log "Installing Spicetify..."
    curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh | sh
    sudo chmod a+wr /var/lib/flatpak/exports/share/applications/com.spotify.Client.desktop 2>/dev/null || true
fi

# Starship
if ! command -v starship &> /dev/null; then
    log "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# 4.5 Shell Setup (Oh My Zsh & Plugins)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

log "Installing Zsh plugins..."
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ] && git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autocomplete" ] && git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git "$ZSH_CUSTOM/plugins/zsh-autocomplete"

# 4.7 Install Nerd Fonts
log "Installing Nerd Fonts..."
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

install_nerd_font() {
    local font_name=$1

    if [ -d "$FONT_DIR/$font_name" ] || ls "$FONT_DIR/$font_name"* &> /dev/null; then
        log "Font $font_name seems to be installed. Skipping..."
        return
    fi

    local zip_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"

    log "Downloading $font_name..."
    wget -q --show-progress -O "/tmp/${font_name}.zip" "$zip_url"

    log "Unzipping $font_name..."
    unzip -o -q "/tmp/${font_name}.zip" -d "$FONT_DIR"

    rm "/tmp/${font_name}.zip"
}

install_nerd_font "JetBrainsMono"
install_nerd_font "FiraCode"

log "Updating font cache..."
fc-cache -fv

# 5. Copy Dotfiles
log "Backing up existing configs to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

# Grub Theme Setup
if [ -d "$DOTFILES_DIR/grub-theme" ]; then
    log "Installing Grub theme..."
    sudo mkdir -p /boot/grub2/themes/
    sudo cp -r "$DOTFILES_DIR/grub-theme" /boot/grub2/themes/

    # Update /etc/default/grub
    if grep -q "GRUB_THEME=" /etc/default/grub; then
        sudo sed -i 's|^GRUB_THEME=.*|GRUB_THEME="/boot/grub2/themes/grub-theme/theme.txt"|' /etc/default/grub
    else
        echo 'GRUB_THEME="/boot/grub2/themes/grub-theme/theme.txt"' | sudo tee -a /etc/default/grub
    fi

    log "Updating Grub config..."
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
fi

# Folders to link
FOLDERS=(
    abrt
    broot
    dconf
    dunst
    flameshot
    gammastep
    ghidra
    ghostty
    grub-theme
    gtk-3.0
    hypr
    i3
    lxqt
    nvim
    org.coolercontrol.CoolerControl
    picom
    polybar
    pulse
    ranger
    rofi
    spicetify
    sway
    swayfx
    Thunar
    waybar
    xfce4
    yazi
)

# Files to link
FILES=(
    mimeapps.list
    pavucontrol.ini
    QtProject.conf
    user-dirs.dirs
    user-dirs.locale
)

for folder in "${FOLDERS[@]}"; do
    if [ -d "$DOTFILES_DIR/$folder" ]; then
        # Backup existing
        if [ -d "$CONFIG_DIR/$folder" ]; then
            log "Backing up $folder..."
            mv "$CONFIG_DIR/$folder" "$BACKUP_DIR/"
        elif [ -L "$CONFIG_DIR/$folder" ]; then
            log "Removing existing symlink for $folder..."
            rm "$CONFIG_DIR/$folder"
        fi

        log "Copying $folder..."
        cp -r "$DOTFILES_DIR/$folder" "$CONFIG_DIR/"
    else
        warn "$folder not found in dotfiles directory, skipping."
    fi
done

for file in "${FILES[@]}"; do
    if [ -f "$DOTFILES_DIR/$file" ]; then
        # Backup existing
        if [ -f "$CONFIG_DIR/$file" ]; then
            log "Backing up $file..."
            mv "$CONFIG_DIR/$file" "$BACKUP_DIR/"
        elif [ -L "$CONFIG_DIR/$file" ]; then
            log "Removing existing symlink for $file..."
            rm "$CONFIG_DIR/$file"
        fi

        log "Copying $file..."
        cp "$DOTFILES_DIR/$file" "$CONFIG_DIR/"
    fi
done

# Handle VS Code
if [ -d "$DOTFILES_DIR/Code/User" ]; then
    log "Configuring VS Code..."
    mkdir -p "$CONFIG_DIR/Code/User"
    mkdir -p "$BACKUP_DIR/Code/User"

    [ -f "$CONFIG_DIR/Code/User/settings.json" ] && mv "$CONFIG_DIR/Code/User/settings.json" "$BACKUP_DIR/Code/User/"
    [ -f "$CONFIG_DIR/Code/User/keybindings.json" ] && mv "$CONFIG_DIR/Code/User/keybindings.json" "$BACKUP_DIR/Code/User/"
    [ -d "$CONFIG_DIR/Code/User/snippets" ] && mv "$CONFIG_DIR/Code/User/snippets" "$BACKUP_DIR/Code/User/"

    cp "$DOTFILES_DIR/Code/User/settings.json" "$CONFIG_DIR/Code/User/settings.json"
    cp "$DOTFILES_DIR/Code/User/keybindings.json" "$CONFIG_DIR/Code/User/keybindings.json"
    cp -r "$DOTFILES_DIR/Code/User/snippets" "$CONFIG_DIR/Code/User/"
fi

# Handle Zsh
if [ -f "$DOTFILES_DIR/.zshrc" ]; then
    log "Copying .zshrc..."
    [ -f "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$BACKUP_DIR/"
    cp "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
fi

# 6. Post-Install Setup
log "Running post-install setup..."

# Change shell to zsh
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    log "Changing default shell to zsh..."
    chsh -s /usr/bin/zsh
fi

echo -e "${GREEN}"
echo "=========================================="
echo "   INSTALLATION COMPLETE"
echo "=========================================="
echo -e "${NC}"
echo "A backup of your old configs is in $BACKUP_DIR."
echo "Please restart your session or reboot to apply changes.
