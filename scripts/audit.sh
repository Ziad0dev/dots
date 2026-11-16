#!/usr/bin/env bash
# audit.sh — the checks that catch what a green build does not: leaked secrets,
# unsafe workflows, sloppy shell, broken Lua, and a NixOS config that quietly
# became insecure or slow. CI (.github/workflows/security.yml) runs exactly this,
# so a local run tells you what CI will say.
#
#   scripts/audit.sh [all|secrets|workflows|shell|lua|policy|vulns]
#
#   all        everything except vulns (the blocking set; this is what CI runs)
#   secrets    gitleaks over the whole git history (allow-list: .gitleaksignore)
#   workflows  actionlint + zizmor on .github/workflows
#   shell      shellcheck (warning+) on tracked shell scripts
#   lua        syntax check of every tracked .lua file
#   nixfmt     every tracked .nix file (except templates/) is formatted
#   policy     security + performance guards on the evaluated NixOS config
#              (tests/policy.nix; DOTS_HOST=<host> to pick another host)
#   vulns      CVEs in the RUNNING system's runtime closure (vulnix). Advisory:
#              needs a built system, ~7 min cold, and NVD matching is noisy.
#
# Missing tools are fetched with `nix shell` from the flake's pinned nixpkgs.
set -o errexit -o nounset -o pipefail

cd "$(git rev-parse --show-toplevel)"

HOST="${DOTS_HOST:-nixos}"

# generated palettes (pure data) are not worth linting
SHELL_EXCLUDE='^config/themes/[^/]+/colors\.sh$'
SHEBANG='^#!\s*(/usr/bin/env\s+)?(/\S*/)?(bash|sh|dash|ksh)(\s|$)'

declare -A NEEDS=(
    [secrets]="gitleaks"
    [workflows]="actionlint zizmor"
    [shell]="shellcheck"
    [lua]="luajit"
    [nixfmt]="nixfmt"
    [policy]="jq"
    [vulns]="vulnix jq"
)

usage() {
    sed -n '2,/^set -o/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
}

# re-exec inside `nix shell` when a tool is missing (once)
ensure_tools() {
    local missing=() pkgs=() t
    for stage in "$@"; do
        for t in ${NEEDS[$stage]:-}; do
            command -v "$t" >/dev/null 2>&1 || {
                missing+=("$t")
                pkgs+=("nixpkgs#$t")
            }
        done
    done
    ((${#missing[@]})) || return 0
    if [[ -n ${DOTS_AUDIT_WRAPPED:-} ]] || ! command -v nix >/dev/null 2>&1; then
        printf 'audit: missing tools (and no nix to fetch them): %s\n' "${missing[*]}" >&2
        exit 127
    fi
    exec nix shell --inputs-from . "${pkgs[@]}" --command env DOTS_AUDIT_WRAPPED=1 bash "$0" "$@"
}

heading() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

# --- stages ---------------------------------------------------------------------

stage_secrets() {
    heading "secrets: gitleaks over all history"
    gitleaks detect --no-banner --redact --log-opts=--all
}

# NB: main() runs every stage as `stage_x || failed+=(x)`, and bash switches
# errexit off for everything inside a function called that way, so a failing
# command only counts if the function's own exit status says so. Each stage
# must therefore return non-zero explicitly; never rely on `set -e` in here.
stage_workflows() {
    local rc=0
    heading "workflows: actionlint"
    actionlint || rc=1
    heading "workflows: zizmor (medium and above)"
    zizmor --no-progress --min-severity medium .github/workflows || rc=1
    return "$rc"
}

stage_shell() {
    heading "shell: shellcheck"
    local files
    mapfile -t files < <(
        git ls-files -z | xargs -0 grep -lIE "$SHEBANG" 2>/dev/null |
            grep -vE '\.nix$' | grep -vE "$SHELL_EXCLUDE" || true
    )
    printf 'checking %d script(s)\n' "${#files[@]}"
    ((${#files[@]})) || return 0
    shellcheck --severity=warning "${files[@]}"
}

stage_lua() {
    heading "lua: syntax"
    local f bad=0
    while IFS= read -r f; do
        luajit -bl "$f" >/dev/null || {
            printf 'syntax error: %s\n' "$f" >&2
            bad=1
        }
    done < <(git ls-files '*.lua')
    return "$bad"
}

stage_nixfmt() {
    heading "nixfmt: formatting"
    git ls-files -z '*.nix' | grep -zv '^templates/' | xargs -0 nixfmt --check
}

stage_policy() {
    heading "policy: $HOST (security + performance guards)"
    [[ $HOST =~ ^[A-Za-z0-9_-]+$ ]] || {
        echo "bad DOTS_HOST: $HOST" >&2
        return 1
    }
    local out
    out="$(nix eval --impure --json --expr \
        "let f = builtins.getFlake (toString ./.); in import ./tests/policy.nix { cfg = f.nixosConfigurations.\"$HOST\".config; }")" || {
        echo "policy: nix eval failed, so nothing was checked" >&2
        return 1
    }
    [[ -n $out ]] || {
        echo "policy: nix eval printed nothing" >&2
        return 1
    }
    jq -r '.stats | to_entries[] | "  \(.key): \(.value)"' <<<"$out" || return 1
    if [[ $(jq '.failures | length' <<<"$out") -gt 0 ]]; then
        jq -r '.failures[] | "FAIL: \(.)"' <<<"$out" >&2
        return 1
    fi
    echo "policy ok"
}

# Advisory: report, never fail. The runtime closure of the running system, high
# severity only, one line per package with the noise NVD adds stripped.
stage_vulns() {
    heading "vulns: CVEs in /run/current-system (advisory)"
    local raw
    raw="$(mktemp)"
    trap 'rm -f "$raw"' RETURN
    vulnix --closure --json /run/current-system >"$raw" || true # exit 2 = "found some"
    printf 'CVSS>=7, deduplicated. NVD matches by version string, so verify before panicking\n'
    printf '(nixpkgs often backports fixes without bumping the version).\n\n'
    jq -r '
        [ .[]
          | select(.version | test("-(tex|texdoc)$") | not)
          | { pname,
              version: (.version | sub("-(fish-completions|man|doc|dev|env|info|bin)$"; "")),
              score: ((.cvssv3_basescore // {}) | [.[]] | max // 0),
              cves: (.affected_by | length) } ]
        | group_by(.pname) | map(max_by(.score)) | map(select(.score >= 7))
        | sort_by(-.score)[]
        | "\(.score)\t\(.pname) \(.version)\t\(.cves) CVE(s)"' "$raw" | column -t -s $'\t'
}

# --- main -----------------------------------------------------------------------

main() {
    local stages=("$@")
    case "${1:-all}" in
    -h | --help | help)
        usage
        return 0
        ;;
    all) stages=(secrets workflows shell lua nixfmt policy) ;;
    secrets | workflows | shell | lua | nixfmt | policy | vulns) ;;
    *)
        printf 'audit: unknown stage: %s\n' "$1" >&2
        usage >&2
        return 2
        ;;
    esac

    ensure_tools "${stages[@]}"

    local failed=() s
    for s in "${stages[@]}"; do
        "stage_$s" || failed+=("$s")
    done

    printf '\n'
    if ((${#failed[@]})); then
        printf '\033[31maudit: FAILED: %s\033[0m\n' "${failed[*]}"
        return 1
    fi
    printf '\033[32maudit: ok (%s)\033[0m\n' "${stages[*]}"
}

main "$@"
