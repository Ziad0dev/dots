#!/bin/bash

# ⸸ Satanic Markdown Setup Script - Fixed Version ⸸
echo "⸸ Setting up markdown rendering tools properly..."

# Update package list
sudo apt update

# Install pandoc for markdown to PDF/HTML conversion
echo "👹 Installing pandoc..."
sudo apt install -y pandoc

# Install comprehensive zathura setup
echo "☠ Installing zathura with all plugins..."
sudo apt install -y \
    zathura \
    zathura-pdf-poppler \
    zathura-djvu \
    zathura-ps \
    zathura-cb \
    poppler-utils

# Install glow properly using official method
echo "🕯 Installing glow (terminal markdown renderer)..."
if ! command -v glow &> /dev/null; then
    # Add glow repository and install
    echo 'deb [trusted=yes] https://repo.charm.sh/apt/ /' | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update
    sudo apt install -y glow
fi

# Install texlive for LaTeX support in pandoc
echo "⛧ Installing texlive for advanced PDF features..."
sudo apt install -y \
    texlive-latex-base \
    texlive-fonts-recommended \
    texlive-latex-extra \
    texlive-xetex \
    texlive-luatex

# Install additional useful packages
echo "🔥 Installing additional utilities..."
sudo apt install -y \
    wkhtmltopdf \
    nodejs \
    npm

# Setup glow config
echo "👹 Setting up glow configuration..."
mkdir -p ~/.config/glow
cat > ~/.config/glow/glow.yml << 'EOF'
# ⸸ Satanic Glow Configuration ⸸
style: "dark"
width: 80
mouse: true
pager: false
EOF

# Install yarn globally (needed for some markdown preview plugins)
if command -v npm &> /dev/null; then
    echo "⛧ Installing yarn..."
    sudo npm install -g yarn
fi

echo "⸸ Setup complete!"
echo ""
echo "Installed tools:"
echo "  ✓ pandoc - Markdown converter"
echo "  ✓ zathura - PDF viewer (with all plugins)"
echo "  ✓ glow - Terminal markdown viewer"
echo "  ✓ texlive - LaTeX support"
echo "  ✓ wkhtmltopdf - HTML to PDF converter"
echo ""
echo "Available keybindings in Neovim:"
echo "  <leader>mp - Toggle markdown preview in browser"
echo "  <leader>mg - Open glow terminal preview"
echo "  <leader>mz - Convert to PDF and open in Zathura"
echo "  <leader>me - Convert to HTML and open in browser" 