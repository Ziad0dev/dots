# dots-bar-tools: helpers for the Rise bar's Omarchy-style tools.
# Every subcommand takes plain arguments (the bar passes argv, never a shell
# string) and prints line-oriented output the QML parses.
#
#   tz <Zone>...            "<Zone> <+HHMM>" per valid zone, "<Zone> invalid" otherwise
#   remind add <sec> <text> one-shot user timer that sends a notification
#   remind list             JSON array: [{unit, next (epoch s), text}]
#   remind cancel <unit>    stop a pending reminder (dots-reminder-* only)
#   disk targets            JSON array of writable mounts to benchmark
#   disk run <dir>          "write|read <MB/s> <bytes>" progress, then "done" or "error <msg>"
#   remote                  "<user> <host> <service>" per remote login session

zoneinfo=${TZDIR:-/etc/zoneinfo}

cmd_tz() {
    local z
    for z in "$@"; do
        # a zone is a relative path under zoneinfo; refuse anything else
        if [[ $z =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]] && [ -f "$zoneinfo/$z" ]; then
            printf '%s %s\n' "$z" "$(TZ="$z" date +%z)"
        else
            printf '%s invalid\n' "$z"
        fi
    done
}

cmd_remind() {
    case "${1:-}" in
        add)
            local sec=${2:-} text=${3:-}
            [[ $sec =~ ^[0-9]+$ ]] && [ "$sec" -ge 1 ] && [ "$sec" -le 2592000 ] || { echo "error: seconds" >&2; exit 2; }
            [ -n "$text" ] || text="Reminder"
            # a transient timer survives a bar restart; the text is an argument
            # to notify-send, never part of a command line string, and systemd
            # must not expand $VARs in it. The timer unloads once it fired.
            systemd-run --user --quiet --collect --expand-environment=no \
                --unit="dots-reminder-$(date +%s%N)" \
                --description="$text" \
                --on-active="${sec}s" --timer-property=AccuracySec=1s \
                --timer-property=RemainAfterElapse=no \
                -- notify-send -a Reminder -u critical -i alarm-symbolic "Reminder" "$text"
            ;;
        list)
            local out='[]' unit next desc
            while read -r unit next; do
                [ -n "$unit" ] || continue
                desc=$(systemctl --user show -p Description --value -- "${unit%.timer}.service")
                out=$(jq -c --arg u "${unit%.timer}" --argjson n "$next" --arg d "$desc" \
                    '. + [{unit: $u, next: ($n / 1000000 | floor), text: $d}]' <<<"$out")
            done < <(systemctl --user list-timers --all --output=json -- 'dots-reminder-*' \
                | jq -r '.[] | select(.next != null and .next > 0) | "\(.unit) \(.next)"')
            jq -c 'sort_by(.next)' <<<"$out"
            ;;
        cancel)
            local unit=${2:-}
            [[ $unit =~ ^dots-reminder-[0-9]+$ ]] || { echo "error: unit" >&2; exit 2; }
            systemctl --user stop -- "$unit.timer" "$unit.service" 2>/dev/null || true
            ;;
        *) echo "usage: dots-bar-tools remind add|list|cancel" >&2; exit 2 ;;
    esac
}

cmd_disk() {
    case "${1:-}" in
        targets)
            # home first, then every real filesystem the user can write to
            {
                printf '%s\t%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}" "Home"
                findmnt -rn -o TARGET,FSTYPE \
                    -t ext4,btrfs,xfs,f2fs,exfat,vfat,ntfs3,ntfs,bcachefs,zfs \
                    | while read -r target fstype; do
                        target=$(printf '%b' "$target")   # findmnt -r escapes spaces as \x20
                        case "$target" in /|/boot|/boot/*|/nix|/nix/*|/var/*|/persist*) continue ;; esac
                        [ -w "$target" ] && printf '%s\t%s\n' "$target" "$target ($fstype)"
                    done
            } | jq -R -s -c '[split("\n")[] | select(length > 0) | split("\t") | {dir: .[0], label: .[1]}]'
            ;;
        run)
            # dd's progress text is parsed below: English, "." decimals
            export LC_ALL=C
            local dir=${2:-} size=$((1024 * 1024 * 1024))
            [ -d "$dir" ] && [ -w "$dir" ] || { echo "error not a writable directory"; exit 0; }
            local free
            free=$(df -B1 --output=avail -- "$dir" | tail -1 | tr -d ' ')
            [ "$free" -gt $((size * 2)) ] || { echo "error needs 2 GiB free"; exit 0; }
            # global, not local: the EXIT trap runs after this function returns
            disk_tmp=$(mktemp -p "$dir" .dots-disk-speed.XXXXXX) || { echo "error cannot create a test file"; exit 0; }
            # removed however the run ends: done, error, panel closed (TERM)
            disk_buf=""
            trap 'rm -f -- "$disk_tmp" ${disk_buf:+"$disk_buf"}' EXIT
            trap 'exit 130' INT TERM HUP

            # dd prints "<bytes> bytes … copied, <s> s, …" with \r between
            # updates; turn each into "<phase> <MB/s> <bytes>"
            progress() {
                tr '\r' '\n' | while read -r line; do
                    if [[ $line =~ ^([0-9]+)\ bytes.*copied,\ ([0-9.]+)\ s ]]; then
                        local b=${BASH_REMATCH[1]} s=${BASH_REMATCH[2]}
                        awk -v p="$1" -v b="$b" -v s="$s" 'BEGIN { if (s > 0) printf "%s %.0f %d\n", p, b / s / 1e6, b }'
                    elif [[ $line =~ (Invalid argument|error|No space) ]]; then
                        echo "error $line"
                    fi
                done
            }
            # direct I/O measures the drive, not the page cache; filesystems
            # without it fall back to a synced write and an uncached-read guess
            local wflag=oflag=direct rflag=iflag=direct note=""
            if ! dd if=/dev/zero of="$disk_tmp" bs=1M count=1 oflag=direct status=none 2>/dev/null; then
                wflag=conv=fdatasync rflag="" note=" (no direct I/O: read may hit the cache)"
            fi
            # random data: zeros would compress to nothing on btrfs compress=zstd
            # and report the CPU, not the drive. A 64 MiB buffer in RAM, written
            # 16 times, keeps urandom's speed out of the measurement.
            disk_buf=$(mktemp -p /dev/shm .dots-disk-speed-buf.XXXXXX)
            head -c $((64 * 1024 * 1024)) /dev/urandom >"$disk_buf"
            # shellcheck disable=SC2086 # empty flags must disappear
            for _ in $(seq $((size / (64 * 1024 * 1024)))); do cat -- "$disk_buf"; done \
                | dd of="$disk_tmp" bs=4M iflag=fullblock $wflag status=progress 2>&1 | progress write
            rm -f -- "$disk_buf"
            # shellcheck disable=SC2086
            dd if="$disk_tmp" of=/dev/null bs=4M $rflag status=progress 2>&1 | progress read
            echo "done$note"
            ;;
        *) echo "usage: dots-bar-tools disk targets|run <dir>" >&2; exit 2 ;;
    esac
}

cmd_remote() {
    local s key val remote host user service
    for s in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
        remote="" host="" user="" service=""
        # show-session prints in its own order, so match the keys
        while IFS='=' read -r key val; do
            case "$key" in
                Remote) remote=$val ;;
                RemoteHost) host=$val ;;
                Name) user=$val ;;
                Service) service=$val ;;
            esac
        done < <(loginctl show-session -p Remote -p RemoteHost -p Name -p Service -- "$s" 2>/dev/null)
        if [ "$remote" = yes ]; then
            printf '%s %s %s\n' "${user:-?}" "${host:--}" "${service:-?}"
        fi
    done
    return 0
}

case "${1:-}" in
    tz) shift; cmd_tz "$@" ;;
    remind) shift; cmd_remind "$@" ;;
    disk) shift; cmd_disk "$@" ;;
    remote) cmd_remote ;;
    *) echo "usage: dots-bar-tools tz|remind|disk|remote …" >&2; exit 2 ;;
esac
