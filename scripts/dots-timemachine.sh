REPO="${DOTS_DIR:-$HOME/dots}"
MARK="$REPO/.git/dots-timemachine"
TAG="dots-timemachine"

die() {
    printf 'dots-timemachine: %s\n' "$1" >&2
    exit 1
}

cd "$REPO" || die "no repo at $REPO"

travel() {
    local commit="$1" branch
    if [ -f "$MARK" ]; then
        git switch --detach --quiet "$commit"
        printf 'now at %s\n' "$(git log -1 --format='%h %s (%cr)')"
        return
    fi
    branch=$(git symbolic-ref --quiet --short HEAD) || die "HEAD is already detached; switch to a branch first"
    if [ -n "$(git status --porcelain)" ]; then
        git stash push --include-untracked --quiet -m "$TAG"
        printf '%s\nstash\n' "$branch" >"$MARK"
    else
        printf '%s\nclean\n' "$branch" >"$MARK"
    fi
    git switch --detach --quiet "$commit"
    printf 'now at %s\n' "$(git log -1 --format='%h %s (%cr)')"
    printf 'run "dots-timemachine back" to return to %s\n' "$branch"
}

back() {
    local branch kind ref
    [ -f "$MARK" ] || die "not time travelling"
    branch=$(sed -n 1p "$MARK")
    kind=$(sed -n 2p "$MARK")
    if [ -n "$(git status --porcelain)" ]; then
        die "the past has uncommitted changes; commit or discard them first"
    fi
    git switch --quiet "$branch"
    if [ "$kind" = stash ]; then
        ref=$(git stash list --format='%gd %s' | awk -v t="$TAG" '$0 ~ t { print $1; exit }')
        if [ -n "$ref" ]; then
            git stash pop --quiet "$ref"
        else
            printf 'warning: the %s stash is gone; nothing to restore\n' "$TAG" >&2
        fi
    fi
    rm -f "$MARK"
    printf 'back on %s\n' "$branch"
}

pick() {
    git log --color=always --format='%C(yellow)%h%C(reset) %C(blue)%cr%C(reset) %s' |
        fzf --ansi --no-sort --prompt 'travel to > ' \
            --preview 'git show --stat --color=always {1}' --preview-window 'right,60%' |
        awk '{print $1}'
}

case "${1:-}" in
    "")
        commit=$(pick)
        [ -n "$commit" ] || exit 0
        travel "$commit"
        ;;
    back) back ;;
    status)
        if [ -f "$MARK" ]; then
            printf 'travelling: at %s, home is %s\n' "$(git log -1 --format='%h %s')" "$(sed -n 1p "$MARK")"
        else
            echo "at home"
        fi
        ;;
    -h | --help | help) printf 'usage: dots-timemachine [back|status|<commit>]\n' ;;
    *) travel "$1" ;;
esac
