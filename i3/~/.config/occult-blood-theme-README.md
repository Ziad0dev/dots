# Occult Blood Red Theme

This theme provides a dark, blood red aesthetic for your desktop environment. Here's how to apply it to different applications:

## i3 Window Manager
The theme is already configured in your i3 config file. The main colors used are:
- Focused windows: deep blood red borders (#8B0000)
- Unfocused windows: darker red borders (#350000)
- Background: very dark red (#100000)

To apply changes, restart i3 with: `Mod+Shift+r`

## Firefox
The Firefox theme is located in `~/.mozilla/firefox/chrome/`. To apply it:

1. Find your Firefox profile folder by going to `about:support` in Firefox
2. Look for "Profile Folder" and click "Open Directory"
3. Create a folder named "chrome" if it doesn't exist
4. Copy the files from `~/.mozilla/firefox/chrome/` to your profile's chrome folder
5. Restart Firefox

## Chromium
A Chromium theme has been created at `~/OccultBloodRed.zip`. To install it:

1. Open Chromium browser
2. Go to `chrome://extensions/`
3. Enable "Developer mode" (toggle in the top right)
4. Drag and drop the `~/OccultBloodRed.zip` file into the extensions page
5. The theme will be applied automatically

If you need to rebuild the theme, run the script:
```bash
~/.config/chromium/OccultBloodRed/pack_theme.sh
```

## Kitty Terminal
The Kitty theme is already configured in `~/.config/kitty/colors.conf`. Any new Kitty window will use this theme.

## Dunst Notifications
The Dunst theme is configured in `~/.config/dunst/dunstrc`. To apply changes:

```bash
killall dunst
dunst &
```

## Picom Compositor
The Picom configuration is in `~/.config/picom/picom.conf`. To apply changes:

```bash
killall picom
picom -b
```

## Custom Wallpaper
The theme uses a blood red wallpaper. It's set in your i3 config to:
```
~/Pictures/1c18ac_42cbb00db5084af6b37c13fd7c79a605~mv2.png
```

## Color Palette
- Primary Red: #8B0000 (Dark Red)
- Secondary Red: #500000 (Deeper Red)
- Background: #100000 (Very Dark Red)
- Accent: #A30000 (Brighter Red)
- Text: #FFFFFF (White) 