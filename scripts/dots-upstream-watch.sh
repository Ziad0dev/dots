cache="${XDG_CACHE_HOME:-$HOME/.cache}/dots-upstream-watch.json"
statedir="${XDG_STATE_HOME:-$HOME/.local/state}/dots/upstream-watch"
watchdir="${DOTS_UPSTREAM_WATCHES:-}"
ttl="${DOTS_UPSTREAM_TTL:-3600}"
mode="${1:-json}"

read_bounded() { dd if="$1" iflag=nofollow,nonblock bs=64k count=8 status=none 2>/dev/null; }

slug() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'; }

store() {
    local f="$statedir/$1" t
    t=$(mktemp "$statedir/.tmp.XXXXXX") || return 1
    if printf '%s\n' "$2" >"$t"; then
        mv -f "$t" "$f" || { rm -f "$t"; return 1; }
    else
        rm -f "$t"
        return 1
    fi
}

recall() {
    local f="$statedir/$1"
    [ -f "$f" ] && [ ! -L "$f" ] || return 0
    read_bounded "$f" | tr -d '[:space:]'
}

raw() { curl -fsSL --proto '=https' --max-time 20 "https://raw.githubusercontent.com/$1/$2/$3"; }

remote_ref() { git ls-remote "$1" "$2" 2>/dev/null | awk 'NR==1 {print $1}'; }

moved() {
    local key now was
    key="ref.$(slug "$1")"
    now="$2"
    [ -n "$now" ] || return 2
    was=$(recall "$key")
    [ "$was" = "$now" ] || store "$key" "$now"
    [ -n "$was" ] && [ "$was" != "$now" ]
}

export statedir
export -f read_bounded slug store recall raw remote_ref moved

emit_error() {
    jq -n --arg e "$1" '{error: $e, checkedAt: "", landed: 0, watches: []}'
    exit 0
}

command -v jq >/dev/null 2>&1 || {
    printf '%s\n' '{"error":"jq not found","checkedAt":"","landed":0,"watches":[]}'
    exit 0
}

case "$mode" in
json | status | notify) ;;
*)
    printf 'usage: dots-upstream-watch {json|status|notify}\n' >&2
    exit 2
    ;;
esac

if [ -z "$watchdir" ] || [ ! -d "$watchdir" ]; then
    emit_error "no watch directory configured"
fi
mkdir -p "$statedir" 2>/dev/null || emit_error "cannot create $statedir"

if [ "$mode" = json ] && [ -f "$cache" ] && [ ! -L "$cache" ]; then
    if [ $(($(date +%s) - $(stat -c %Y "$cache"))) -lt "$ttl" ]; then
        cached=$(read_bounded "$cache")
        if [ -n "$cached" ] && jq -e . <<<"$cached" >/dev/null 2>&1; then
            printf '%s\n' "$cached"
            exit 0
        fi
    fi
fi

rows=""
for w in "$watchdir"/*/; do
    [ -d "$w" ] || continue
    name=$(basename "$w")
    desc=""
    url=""
    [ -f "$w/description" ] && desc=$(read_bounded "$w/description")
    [ -f "$w/url" ] && url=$(read_bounded "$w/url")

    if [ -x "$w/check" ]; then
        detail=$(timeout 90 "$w/check" 2>&1)
        rc=$?
    else
        detail="watch has no executable check"
        rc=3
    fi

    case "$rc" in
    0) state=landed ;;
    1) state=waiting ;;
    124)
        state=error
        detail="check timed out"
        ;;
    *) state=error ;;
    esac

    row=$(jq -n --arg n "$name" --arg d "$desc" --arg u "$url" --arg s "$state" --arg t "$detail" '{
        name: $n,
        description: ($d | rtrimstr("\n")),
        url: ($u | rtrimstr("\n") | if startswith("https://") then . else "" end),
        state: $s,
        detail: ($t | rtrimstr("\n") | .[0:600])
    }') || continue
    rows="$rows$row"$'\n'
done

out=$(printf '%s' "$rows" | jq -s --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
    error: "",
    checkedAt: $t,
    watches: (. | sort_by(.state != "landed", .name)),
    landed: (map(select(.state == "landed")) | length)
}') || emit_error "failed to assemble watch results"

[ -n "$out" ] || emit_error "empty watch result"

if tmp=$(mktemp "$cache.XXXXXX" 2>/dev/null); then
    if printf '%s\n' "$out" >"$tmp"; then
        mv -f "$tmp" "$cache" || rm -f "$tmp"
    else
        rm -f "$tmp"
    fi
fi

case "$mode" in
json)
    printf '%s\n' "$out"
    ;;
notify)
    while IFS=$'\t' read -r n s d; do
        [ -n "$n" ] || continue
        key="state.$(slug "$n")"
        prev=$(recall "$key")
        if [ "$s" = landed ] && [ "$prev" != landed ]; then
            notify-send -a dots-upstream -u normal "Upstream fix landed" "${d:-$n}" 2>/dev/null || true
        fi
        store "$key" "$s"
    done < <(printf '%s' "$out" | jq -r '.watches[] | [.name, .state, .description] | @tsv')
    ;;
status)
    printf '%s' "$out" | jq -r '
        (if .error != "" then "error: " + .error else empty end),
        ("checked " + .checkedAt),
        "",
        (.watches[] |
            (if .state == "landed" then "LANDED " elif .state == "waiting" then "waiting" else "error  " end)
            + "  " + .name
            + (if .description != "" then "  " + .description else "" end)
            + (if .url != "" then "\n           " + .url else "" end)
            + (if .detail != "" then "\n           " + (.detail | gsub("\n"; "\n           ")) else "" end)),
        "",
        ("landed " + (.landed | tostring) + " of " + (.watches | length | tostring))
    '
    ;;
esac
