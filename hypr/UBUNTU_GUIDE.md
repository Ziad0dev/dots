# 🐧 Ubuntu Compatibility Guide for Hyprland Setup

## ✅ Ubuntu Compatibility Status

**Short Answer**: Yes, this Hyprland setup works on Ubuntu, but requires additional setup steps.

**Ubuntu Versions Supported**:
- Ubuntu 22.04 LTS (Jammy) - ⚠️ Requires PPAs/building from source
- Ubuntu 23.04+ (Lunar and newer) - ✅ Better package availability
- Ubuntu 24.04 LTS (Noble) - ✅ Recommended for best experience

## 🚀 Quick Ubuntu Installation

```bash
cd ~/dots/hypr
chmod +x install.sh
./install.sh
```

The installation script automatically detects Ubuntu and handles package differences.

## 📦 Ubuntu Package Differences

### Automatically Handled
| Arch Package | Ubuntu Package | Notes |
|---|---|---|
| `python-pywal` | `python3-pywal` | Auto-converted |
| `polkit-gnome` | `policykit-1-gnome` | Auto-converted |
| `notify-send` | `libnotify-bin` | Auto-converted |
| `network-manager-applet` | `network-manager-gnome` | Auto-converted |

### Special Installations
| Package | Ubuntu Method | Status |
|---|---|---|
| `hyprland` | PPA or build from source | Automated |
| `swww` | Cargo install | Automated |
| `cliphist` | Go install | Automated |
| `xdg-desktop-portal-hyprland` | With Hyprland | Automated |

## 🔧 Manual Ubuntu Setup (if script fails)

### 1. Install Hyprland

#### Option A: PPA (Recommended)
```bash
sudo add-apt-repository ppa:hyprwm/hyprland
sudo apt update
sudo apt install hyprland
```

#### Option B: Build from Source
```bash
# Install dependencies
sudo apt install build-essential cmake ninja-build pkg-config \
  libwayland-dev libxkbcommon-dev libpixman-1-dev \
  libdrm-dev libgtk-3-dev

# Clone and build
git clone --recursive https://github.com/hyprwm/Hyprland
cd Hyprland
make all
sudo make install
```

### 2. Install Additional Tools

```bash
# Install available packages
sudo apt update
sudo apt install waybar rofi dunst kitty pipewire pipewire-pulse \
  wireplumber grim slurp wl-clipboard policykit-1-gnome \
  xdg-desktop-portal-gtk python3-pywal libnotify-bin \
  pavucontrol network-manager-gnome translate-shell khal

# Install Rust for swww
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
cargo install swww

# Install Go for cliphist  
sudo apt install golang-go
go install go.senan.xyz/cliphist@latest
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
```

## 🖥️ Display Manager Setup

### For GDM (Default Ubuntu)
Hyprland should appear automatically in the session list after installation.

### For LightDM
```bash
sudo apt install lightdm
sudo systemctl enable lightdm
```

### For SDDM
```bash
sudo apt install sddm
sudo systemctl enable sddm
```

## ⚡ Ubuntu-Specific Optimizations

### 1. Enable Pipewire (Ubuntu 22.04+)
```bash
systemctl --user enable pipewire pipewire-pulse wireplumber
systemctl --user start pipewire pipewire-pulse wireplumber
```

### 2. Fix Font Rendering
```bash
sudo apt install fonts-noto fonts-noto-color-emoji
sudo fc-cache -fv
```

### 3. Install JetBrains Mono Font
```bash
wget https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip
unzip JetBrainsMono-2.304.zip
sudo cp fonts/ttf/*.ttf /usr/share/fonts/
sudo fc-cache -fv
```

## 🔍 Troubleshooting Ubuntu Issues

### Hyprland Won't Start
```bash
# Check if installed correctly
which hyprland
hyprland --version

# Check dependencies
ldd $(which hyprland)

# Run from TTY for error messages
sudo systemctl stop gdm3
# Switch to TTY (Ctrl+Alt+F3)
Hyprland
```

### Waybar Not Showing
```bash
# Install missing dependencies
sudo apt install libgtkmm-3.0-dev libpulse-dev

# Check if waybar is built with required features
waybar --version
```

### Audio Issues
```bash
# Ensure pipewire is running
systemctl --user status pipewire
systemctl --user status pipewire-pulse

# Remove pulseaudio if conflicting
sudo apt remove pulseaudio
```

### Missing Icons
```bash
# Install icon theme
sudo apt install papirus-icon-theme
```

## 🎯 Ubuntu Performance Tips

### 1. Disable Ubuntu's Built-in Compositor
```bash
# For GNOME
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

# Or switch to a lighter desktop for login
sudo apt install xfce4-session
```

### 2. Enable Hardware Acceleration
```bash
# For Intel graphics
sudo apt install intel-media-va-driver

# For AMD graphics  
sudo apt install mesa-va-drivers

# For NVIDIA
sudo apt install nvidia-driver-535 # or latest version
```

### 3. Optimize Memory Usage
Add to `/etc/sysctl.conf`:
```
vm.swappiness=10
vm.vfs_cache_pressure=50
```

## 📋 Ubuntu Compatibility Checklist

- [ ] Ubuntu 22.04+ installed
- [ ] Hyprland PPA added or built from source
- [ ] Rust installed for swww
- [ ] Go installed for cliphist
- [ ] Pipewire enabled and running
- [ ] JetBrains Mono font installed
- [ ] All configuration files symlinked
- [ ] Display manager configured

## 🆘 Getting Help

### Ubuntu-Specific Issues
- [Ubuntu Hyprland PPA](https://launchpad.net/~hyprwm/+archive/ubuntu/hyprland)
- [Ubuntu Forums - Wayland](https://ubuntuforums.org/forumdisplay.php?f=336)

### Hyprland General Issues
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Hyprland GitHub Issues](https://github.com/hyprwm/Hyprland/issues)

## 🎉 Success on Ubuntu!

Once set up, your Hyprland configuration will work identically to Arch Linux, with all your occult theming and workflow preserved!

**The darkness adapts to any distribution! 🖤**
