#!/bin/bash

# Create the unpacked directory structure
rm -rf ~/OccultBloodRedUnpacked
mkdir -p ~/OccultBloodRedUnpacked/images

# Copy images
cp images/theme_*.png ~/OccultBloodRedUnpacked/images/

# Create the manifest.json file
cat > ~/OccultBloodRedUnpacked/manifest.json << 'EOF'
{
  "name": "Occult Blood Red",
  "version": "1.0",
  "description": "A dark occult blood red theme",
  "manifest_version": 3,
  "theme": {
    "images": {
      "theme_frame": "images/theme_frame.png",
      "theme_toolbar": "images/theme_toolbar.png",
      "theme_ntp_background": "images/theme_ntp_background.png"
    },
    "colors": {
      "frame": [16, 0, 0],
      "toolbar": [34, 0, 0],
      "tab_text": [255, 255, 255],
      "tab_background_text": [170, 170, 170],
      "bookmark_text": [255, 255, 255],
      "ntp_background": [16, 0, 0],
      "ntp_text": [255, 255, 255],
      "ntp_link": [163, 0, 0],
      "button_background": [139, 0, 0]
    },
    "tints": {
      "buttons": [0.55, 0.0, 0.9],
      "frame": [0.55, 0.0, 0.9],
      "frame_inactive": [0.30, 0.0, 0.75]
    },
    "properties": {
      "ntp_background_alignment": "center",
      "ntp_background_repeat": "no-repeat",
      "ntp_logo_alternate": 1
    }
  }
}
EOF

echo "Created unpacked extension at ~/OccultBloodRedUnpacked"
echo ""
echo "To install, go to chrome://extensions/, enable Developer mode,"
echo "then click 'Load unpacked' and select ~/OccultBloodRedUnpacked" 