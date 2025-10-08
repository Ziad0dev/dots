#!/bin/bash

# Create a zip file of the theme
cd ~/.config/chromium/OccultBloodRed
zip -r ~/OccultBloodRed.zip *

# Instructions
echo "=== Occult Blood Red Theme Created ==="
echo ""
echo "To install the theme in Chromium:"
echo "1. Open Chromium browser"
echo "2. Go to chrome://extensions/"
echo "3. Enable 'Developer mode' (toggle in the top right)"
echo "4. Drag and drop the ~/OccultBloodRed.zip file into the extensions page"
echo ""
echo "Theme file created at: ~/OccultBloodRed.zip" 