usage() {
    printf 'usage: dots-gif <video> [-s start] [-t seconds] [-f fps] [-w width] [-o out.gif]\n' >&2
    exit 1
}

[ $# -ge 1 ] || usage
in="$1"
shift
[ -f "$in" ] || { printf 'dots-gif: no such file: %s\n' "$in" >&2; exit 1; }

start="" dur="" fps=15 width=720 out="${in%.*}.gif"
while getopts "s:t:f:w:o:" opt; do
    case "$opt" in
        s) start="$OPTARG" ;;
        t) dur="$OPTARG" ;;
        f) fps="$OPTARG" ;;
        w) width="$OPTARG" ;;
        o) out="$OPTARG" ;;
        *) usage ;;
    esac
done

[[ "$fps" =~ ^[0-9]+$ ]] || usage
[[ "$width" =~ ^[0-9]+$ ]] || usage

trim=()
[ -n "$start" ] && trim+=(-ss "$start")
[ -n "$dur" ] && trim+=(-t "$dur")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

filters="fps=$fps,scale=$width:-1:flags=lanczos"

safe=(-protocol_whitelist file)

ffmpeg -v error -stats "${trim[@]}" "${safe[@]}" -i "file:$in" \
    -vf "$filters,palettegen=stats_mode=diff" -y "file:$tmp/palette.png"
ffmpeg -v error -stats "${trim[@]}" "${safe[@]}" -i "file:$in" "${safe[@]}" -i "file:$tmp/palette.png" \
    -lavfi "$filters [x]; [x][1:v] paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
    -loop 0 -y "file:$out"

printf '%s (%s)\n' "$out" "$(du -h "$out" | cut -f1)"
