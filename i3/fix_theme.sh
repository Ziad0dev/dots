#!/bin/bash

# Delete any existing zip file
rm -f ~/OccultBloodRed.zip

# Create a temporary directory with a process ID to avoid conflicts
TEMP_DIR="/tmp/chrometheme-build-$$"
mkdir -p "$TEMP_DIR/images"

# Copy only the necessary files
cp manifest.json "$TEMP_DIR/"
cp images/theme_*.png "$TEMP_DIR/images/"

# Create the zip file from the temp directory and not the current one
(cd "$TEMP_DIR" && zip -r ~/OccultBloodRed.zip *)

# Clean up the temporary directory
rm -rf "$TEMP_DIR"

# Verify the contents
echo "Verifying package contents:"
unzip -l ~/OccultBloodRed.zip

echo ""
echo "=== Occult Blood Red Theme Created ==="
echo ""
echo "To install the theme in Chromium/Chrome:"
echo "1. Open Chrome/Chromium browser"
echo "2. Go to chrome://extensions/"
echo "3. Enable 'Developer mode' (toggle in the top right)"
echo "4. Drag and drop the ~/OccultBloodRed.zip file into the extensions page"
echo ""
echo "Theme file created successfully at: ~/OccultBloodRed.zip"
echo "File size: $(du -h ~/OccultBloodRed.zip | cut -f1)" 