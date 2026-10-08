#!/bin/bash
# List desktop applications for the launcher
# from github.com/bgibson72/yahr-quickshell with modifications
# Blacklist - apps to hide (add desktop file basenames here)
BLACKLIST=(
    "xfce4-about.desktop"
    "avahi-discover.desktop"
    "bssh.desktop"
    "bvnc.desktop"
    "qv4l2.desktop"
    "qvidcap.desktop"
    "lstopo.desktop"
    "uuctl.desktop"
    "codium.desktop"          # Hide regular VSCodium (keep Wayland version)
    "xgps.desktop"            # Hide Xgps
    "xgpsspeed.desktop"       # Hide Xgpsspeed
)

# Whitelist - always include these desktop files
WHITELIST=(
    "wallpaper.desktop" 
    "theme.desktop"
    "powermenu.desktop"
)

# Data dirs, local first so overrides work. rise: from XDG_DATA_DIRS (NixOS
# keeps applications and icons in the profiles, not /usr/share).
DATA_DIRS=("$HOME/.local/share")
IFS=: read -r -a _xdg <<<"${XDG_DATA_DIRS:-/etc/profiles/per-user/$USER/share:/run/current-system/sw/share:/usr/local/share:/usr/share}"
DATA_DIRS+=("${_xdg[@]}" "/etc/profiles/per-user/$USER/share" "/run/current-system/sw/share" "/usr/share")

# Search paths for .desktop files
SEARCH_PATHS=()
for d in "${DATA_DIRS[@]}"; do SEARCH_PATHS+=("$d/applications"); done
SEARCH_PATHS+=("$HOME/.local/share/flatpak/exports/share/applications" "/var/lib/flatpak/exports/share/applications")

# Function to find icon path
find_icon() {
    local icon_name="$1"
    local theme="Papirus"
    icon_name="${icon_name#theme://}"
    [[ "$icon_name" == /* ]] && { echo "$icon_name"; return; }

    local exts=(png svg xpm)
    local sizes=(64 48 128 256 32 24 22 16 512 scalable) # rise: crisp ones first
    local icon_bases=()
    local d
    for d in "${DATA_DIRS[@]}"; do icon_bases+=("$d/icons/$theme"); done
    for d in "${DATA_DIRS[@]}"; do icon_bases+=("$d/icons/hicolor"); done

    for base in "${icon_bases[@]}"; do
        for size in "${sizes[@]}"; do
            for ext in "${exts[@]}"; do
                for subdir in apps actions status devices places panel mimetypes; do
                    local candidate="$base/${size}x${size}/$subdir/$icon_name.$ext"
                    [[ -f "$candidate" ]] && { echo "$candidate"; return; }
                done
                local scalable="$base/scalable/apps/$icon_name.$ext"
                [[ -f "$scalable" ]] && { echo "$scalable"; return; }
            done
        done
    done

    for d in "${DATA_DIRS[@]}"; do
        for ext in "${exts[@]}"; do
            [[ -f "$d/pixmaps/$icon_name.$ext" ]] && { echo "$d/pixmaps/$icon_name.$ext"; return; }
        done
    done

    echo "$icon_name"
}

# Collect all desktop files and process
declare -A seen_apps

for dir in "${SEARCH_PATHS[@]}"; do
    [ ! -d "$dir" ] && continue
    
    while IFS= read -r desktop_file; do
        basename_file=$(basename "$desktop_file")
        
        # Skip duplicates (local overrides system)
        [[ -n "${seen_apps[$basename_file]}" ]] && continue
        seen_apps[$basename_file]=1
        
        # Skip blacklisted unless whitelisted
        skip=0
        for blacklisted in "${BLACKLIST[@]}"; do
            [[ "$basename_file" == "$blacklisted" ]] && skip=1 && break
        done
        # Check whitelist override
        for whitelisted in "${WHITELIST[@]}"; do
            [[ "$basename_file" == "$whitelisted" ]] && skip=0 && break
        done
        [[ $skip -eq 1 ]] && continue
        
        # Skip if NoDisplay=true
        grep -q "^NoDisplay=true" "$desktop_file" 2>/dev/null && continue
        
        # Extract fields
        name=$(grep "^Name=" "$desktop_file" | head -1 | cut -d= -f2-)
        comment=$(grep "^Comment=" "$desktop_file" | head -1 | cut -d= -f2-)
        icon=$(grep "^Icon=" "$desktop_file" | head -1 | cut -d= -f2-)
        exec=$(grep "^Exec=" "$desktop_file" | head -1 | cut -d= -f2- | sed 's/%[uUfF]//g' | sed 's/%[cdnNvmki]//g')
        
        # Skip if no name or exec
        [ -z "$name" ] && continue
        [ -z "$exec" ] && continue
        
        # Default comment
        [ -z "$comment" ] && comment="Application"
        
        # Find icon
        icon_path=$(find_icon "$icon")
        
        # Output
        echo "$name|$comment|$icon_path|$exec"
        
    done < <(find -L "$dir" -name "*.desktop" -type f 2>/dev/null)
done | sort -u
