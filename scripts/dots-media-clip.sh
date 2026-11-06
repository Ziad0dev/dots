# dots-media-clip play|download -- act on the URL in the clipboard.
#   play      open it in mpv (mpv resolves it through yt-dlp: Twitch, YouTube, ...)
#   download  save it into ~/Videos/Downloads with yt-dlp
notify() { notify-send -a dots-media "$@" || true; }

mode=${1:-play}

url=$(wl-paste --no-newline 2>/dev/null || true)
url=${url%%$'\n'*}
case "$url" in
    http://* | https://*) ;;
    *)
        notify -u critical "Media" "clipboard has no http(s) URL"
        exit 1
        ;;
esac

case "$mode" in
    play)
        notify "mpv" "$url"
        setsid -f mpv --force-window=immediate -- "$url" >/dev/null 2>&1
        ;;
    download)
        dir="$(xdg-user-dir VIDEOS)/Downloads"
        mkdir -p "$dir"
        notify "yt-dlp" "downloading $url"
        (
            if yt-dlp --no-playlist -P "$dir" -o '%(title).150B [%(id)s].%(ext)s' -- "$url" >/dev/null 2>&1; then
                notify "yt-dlp" "saved to $dir"
            else
                notify -u critical "yt-dlp" "download failed: $url"
            fi
        ) >/dev/null 2>&1 &
        ;;
    *)
        notify -u critical "Media" "unknown mode: $mode"
        exit 2
        ;;
esac
