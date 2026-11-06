#!/usr/bin/env bash
# dots-pdf — the Acrobat-shaped toolbox for the terminal and for Neovim (:Pdf).
# Every command writes a NEW file next to the input and never touches the
# original. Signing lives in dots-pdfsign.
set -o errexit -o nounset -o pipefail

ANNOT_JS="${DOTS_PDF_JS:-$(dirname "$(readlink -f "$0")")/dots-pdf-annot.js}"
OCR_LANG="${DOTS_PDF_OCR_LANG:-eng}"

OUT=""
FORCE=0
ARGS=()
TMP=""
cleanup() { [[ -z $TMP ]] || rm -rf "$TMP"; }
trap cleanup EXIT

die() {
    printf 'dots-pdf: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
usage: dots-pdf <command> [-o OUT] [--force] [--] ...
  (after `--` nothing is treated as an option: use it for text that may start with a dash)

READ
  info <pdf>                       metadata, size, encryption, signatures, forms
  text <pdf> [out.txt]             extract text, layout preserved
  grep <pdf> <regex>               search with page numbers
  find <pdf> <term>                locate text: "page x1 y1 x2 y2" (points, bottom-left)
  outline <pdf>                    bookmarks
  annots <pdf>                     list annotations
  images <pdf> [dir]               extract embedded images
  render <pdf> <page> [dpi] [out.png]
  diff <a.pdf> <b.pdf>             text diff of two PDFs

ORGANISE                           (ranges: 1-3,5,z   z = last page)
  merge a.pdf b.pdf ... -o OUT
  extract <pdf> <range>            keep only these pages
  delete <pdf> <range>
  reorder <pdf> <range>            e.g. 3,1,2,4-z
  rotate <pdf> <90|180|270> [range]
  split <pdf> [pages-per-file]     into a directory next to the file
  crop <pdf> <desc> [range]        '[x1 y1 x2 y2]' (points) or '20' (mm margin)
  number <pdf> [format]            page numbers, default "Page %p of %P"
  watermark <pdf> <text> [desc]    diagonal grey text; desc = pdfcpu description

MARK UP  (real annotations; sign last — later edits show as modifications)
  highlight|underline|strike|squiggly <pdf> <term> [color] [pages]
  note <pdf> <page> <x> <y> <text>
  text-add <pdf> <page> <x> <y> <size> <text>      (alias: fill)
  text-add <pdf> --after "Name:" <size> <text>     place right after an anchor
  image <pdf> <png> <page> <x> <y> <width>         stamp a picture / ink signature
  image <pdf> <png> --after "Signature:" <width>
  redact <pdf> --text TERM         permanently remove matching text (rewrites file)
  redact <pdf> --box PAGE:x1,y1,x2,y2

FORMS
  form list|export|fill|flatten <pdf> [json]
  flatten <pdf>                    bake forms & annotations into the page

DOCUMENT
  compress <pdf> [screen|ebook|printer|prepress]
  optimize <pdf>                   linearise for fast web view
  ocr <pdf>                        make scanned pages searchable (DOTS_PDF_OCR_LANG)
  encrypt <pdf> [--no-print] [--no-copy] [--no-modify]
  decrypt <pdf>                    password: env DOTS_PDF_PASS or prompt
  meta <pdf> [Title=.. Author=.. Subject=.. Keywords=..|--strip]
  bookmarks export|import|clear <pdf> [json]
  attach add|list|extract <pdf> [files... | dir]

CONVERT
  to-images <pdf> [png|jpg] [dpi]
  from-images <img>... -o OUT
  from-office <doc>                needs LibreOffice (soffice) on PATH

GUI HANDOFF
  gui view|annotate|arrange|edit <pdf>
      annotate = Xournal++ (freehand ink, drawn signature, shapes)
      arrange  = PDF Arranger (drag pages around)
      edit     = LibreOffice Draw (change existing text/objects)
EOF
}

# --- helpers -----------------------------------------------------------------

need_pdf() {
    [[ -n ${1:-} ]] || die "no PDF given"
    [[ -f $1 ]] || die "not a file: $1"
}

mktmp() {
    [[ -n $TMP ]] || TMP="$(mktemp -d)"
}

# destination: -o PATH (refuses to clobber), or <input>.<suffix>[-N].pdf
dest() {
    local pdf="$1" suffix="$2" out n=1
    if [[ -n $OUT ]]; then
        out="$OUT"
        if [[ -e $out && $FORCE -eq 0 ]]; then
            die "already exists: $out (use --force)"
        fi
    else
        local base="${pdf%.pdf}"
        # marking up twice gives x.marked-2.pdf, not x.marked.marked.pdf
        if [[ $base =~ ^(.*)\.$suffix(-[0-9]+)?$ ]]; then base="${BASH_REMATCH[1]}"; fi
        out="$base.$suffix.pdf"
        while [[ -e $out ]]; do
            n=$((n + 1))
            out="$base.$suffix-$n.pdf"
        done
    fi
    [[ $out != "$pdf" ]] || die "refusing to overwrite the original"
    printf '%s' "$out"
}

pages() { pdfinfo "$1" | awk '$1 == "Pages:" { print $2 }'; }

# replace z with the real last page number (pdfcpu has no `z`)
norm_range() {
    local n
    n="$(pages "$1")"
    printf '%s' "${2//z/$n}"
}

secret() {
    local var="$1" prompt="$2" val
    if [[ -v $var ]]; then
        printf '%s' "${!var}"
    elif [[ -t 0 ]]; then
        read -rsp "$prompt" val
        printf '\n' >&2
        printf '%s' "$val"
    else
        die "need a password: set $var or run from a terminal"
    fi
}

annot() { mutool run "$ANNOT_JS" "$@"; }

# like annot, for modes that write <in> <out>: drop the partial copy on failure
annot_out() {
    local out="$3" rc=0
    mutool run "$ANNOT_JS" "$@" || rc=$?
    ((rc == 0)) || rm -f "$out"
    return "$rc"
}

pcpu() { pdfcpu -c disable "$@"; }

# qpdf exits 3 for "finished, with warnings" (a PDF it had to repair): the
# output file is complete and valid. Treating that as failure aborted the
# command before it printed the output path, so callers saw an error for a
# file that was in fact written.
qpdf() {
    local rc=0
    command qpdf "$@" || rc=$?
    if ((rc == 3)); then
        printf 'dots-pdf: qpdf finished with warnings\n' >&2
        return 0
    fi
    return "$rc"
}

# run quietly, but show the output if it fails
quiet() {
    local log
    log="$("$@" 2>&1)" || {
        printf '%s\n' "$log" >&2
        return 1
    }
}

done_msg() { printf '%s\n' "$1"; }

# "PAGE X1 Y1 X2 Y2" of the LAST occurrence of a term
last_hit() {
    local hit
    hit="$(annot find "$1" - "$2" | tail -n 1)"
    [[ -n $hit ]] || die "text not found: $2"
    printf '%s' "$hit"
}

# --- read --------------------------------------------------------------------

cmd_info() {
    need_pdf "${1:-}"
    pdfinfo "$1"
    printf '\n-- signatures --\n'
    pyhanko sign list "$1" 2>/dev/null || true
    printf '\n-- form fields --\n'
    pcpu form list "$1" 2>&1 | head -40 || true
    printf '\n-- attachments --\n'
    pcpu attachments list "$1" 2>&1 | head -20 || true
}

cmd_text() {
    need_pdf "${1:-}"
    if [[ -n ${2:-} ]]; then pdftotext -layout "$1" "$2"; else pdftotext -layout "$1" -; fi
}

cmd_grep() {
    need_pdf "${1:-}"
    [[ -n ${2:-} ]] || die "no pattern given"
    pdfgrep -n -i --color never -- "$2" "$1"
}

cmd_find() {
    need_pdf "${1:-}"
    [[ -n ${2:-} ]] || die "no term given"
    annot find "$1" - "$2"
}

cmd_outline() {
    need_pdf "${1:-}"
    pcpu bookmarks list "$1"
}

cmd_annots() {
    need_pdf "${1:-}"
    pcpu annotations list "$1"
}

cmd_images() {
    need_pdf "${1:-}"
    local dir="${2:-${1%.pdf}.images}"
    mkdir -p "$dir"
    pdfimages -all "$1" "$dir/img"
    printf '%s\n' "$dir"
}

cmd_render() {
    need_pdf "${1:-}"
    local page="${2:-1}" dpi="${3:-110}" out="${4:-}"
    out="${out:-${OUT:-${1%.pdf}.p$page.png}}"
    pdftoppm -r "$dpi" -f "$page" -l "$page" -png -singlefile "$1" "${out%.png}"
    printf '%s\n' "$out"
}

cmd_diff() {
    need_pdf "${1:-}"
    need_pdf "${2:-}"
    diff -u --label "$1" --label "$2" <(pdftotext -layout "$1" -) <(pdftotext -layout "$2" -) || true
}

# --- organise ----------------------------------------------------------------

cmd_merge() {
    (($# >= 2)) || die "merge needs at least two PDFs"
    local f
    for f in "$@"; do need_pdf "$f"; done
    local out n=1
    if [[ -n $OUT ]]; then
        out="$OUT"
        [[ ! -e $out || $FORCE -eq 1 ]] || die "already exists: $out (use --force)"
    else
        out="$(dirname "$1")/merged.pdf"
        while [[ -e $out ]]; do
            n=$((n + 1))
            out="$(dirname "$1")/merged-$n.pdf"
        done
    fi
    qpdf --empty --pages "$@" -- "$out"
    done_msg "$out"
}

cmd_extract() {
    need_pdf "${1:-}"
    [[ -n ${2:-} ]] || die "no page range given"
    local out
    out="$(dest "$1" pages)"
    qpdf "$1" --pages . "$2" -- "$out"
    done_msg "$out"
}

cmd_delete() {
    need_pdf "${1:-}"
    [[ -n ${2:-} ]] || die "no page range given"
    local out
    out="$(dest "$1" trimmed)"
    quiet pcpu pages remove -p "$(norm_range "$1" "$2")" "$1" "$out"
    done_msg "$out"
}

cmd_reorder() {
    need_pdf "${1:-}"
    [[ -n ${2:-} ]] || die "no page order given"
    local out
    out="$(dest "$1" reordered)"
    qpdf "$1" --pages . "$2" -- "$out"
    done_msg "$out"
}

cmd_rotate() {
    need_pdf "${1:-}"
    local deg="${2:-}" range="${3:-1-z}"
    case "$deg" in
    90 | 180 | 270) ;;
    -90) deg=270 ;;
    *) die "rotation must be 90, 180, 270 or -90" ;;
    esac
    local out
    out="$(dest "$1" rotated)"
    qpdf "$1" --rotate="+$deg:$range" "$out"
    done_msg "$out"
}

cmd_split() {
    need_pdf "${1:-}"
    local span="${2:-1}" dir
    dir="${OUT:-${1%.pdf}.split}"
    mkdir -p "$dir"
    quiet pcpu split "$1" "$dir" "$span"
    printf '%s\n' "$dir"
}

cmd_crop() {
    need_pdf "${1:-}"
    [[ -n ${2:-} ]] || die "no crop description given"
    local out
    out="$(dest "$1" cropped)"
    local unit=(-u mm)
    [[ $2 != \[* ]] || unit=(-u po)
    if [[ -n ${3:-} ]]; then
        quiet pcpu crop "${unit[@]}" -p "$(norm_range "$1" "$3")" -- "$2" "$1" "$out"
    else
        quiet pcpu crop "${unit[@]}" -- "$2" "$1" "$out"
    fi
    done_msg "$out"
}

cmd_number() {
    need_pdf "${1:-}"
    local fmt="${2:-Page %p of %P}" out
    out="$(dest "$1" numbered)"
    quiet pcpu stamp add -m text -- "$fmt" \
        "pos:bc, off:0 22, points:9, fillc:.35 .35 .35, scale:1 abs, rot:0" "$1" "$out"
    done_msg "$out"
}

cmd_watermark() {
    need_pdf "${1:-}"
    [[ -n ${2:-} ]] || die "no watermark text given"
    local desc="${3:-rot:45, scale:.55 rel, points:90, fillc:.5 .5 .5, op:.22}" out
    out="$(dest "$1" watermarked)"
    quiet pcpu watermark add -m text -- "$2" "$desc" "$1" "$out"
    done_msg "$out"
}

# --- mark up -----------------------------------------------------------------

cmd_mark() {
    local kind="$1"
    shift
    need_pdf "${1:-}"
    [[ -n ${2:-} ]] || die "no search term given"
    local out
    out="$(dest "$1" marked)"
    annot_out mark "$1" "$out" "$kind" "$2" "${3:-}" "${4:-all}" >&2
    done_msg "$out"
}

cmd_note() {
    need_pdf "${1:-}"
    (($# >= 5)) || die "usage: note <pdf> <page> <x> <y> <text>"
    local pdf="$1" page="$2" x="$3" y="$4" out
    shift 4
    out="$(dest "$pdf" noted)"
    annot_out note "$pdf" "$out" "$page" "$x" "$y" "$*" >/dev/null
    done_msg "$out"
}

cmd_text_add() {
    need_pdf "${1:-}"
    local pdf="$1" page x y size out
    shift
    if [[ ${1:-} == --after ]]; then
        local hit hy1 hx2
        hit="$(last_hit "$pdf" "${2:-}")"
        read -r page _ hy1 hx2 _ <<<"$hit"
        size="${3:-11}"
        x="$(awk -v v="$hx2" 'BEGIN { print v + 6 }')"
        # y is the bottom of the text box: sit the baseline on the anchor's baseline
        y="$(awk -v v="$hy1" -v s="$size" 'BEGIN { print v - 0.4 * s - 1 }')"
        shift 3
    else
        (($# >= 5)) || die "usage: text-add <pdf> <page> <x> <y> <size> <text>"
        page="$1" x="$2" y="$3" size="$4"
        shift 4
    fi
    [[ -n ${*:-} ]] || die "no text given"
    out="$(dest "$pdf" filled)"
    annot_out freetext "$pdf" "$out" "$page" "$x" "$y" "$size" "$*" >/dev/null
    done_msg "$out"
}

cmd_image() {
    need_pdf "${1:-}"
    local pdf="$1" img="${2:-}" page x y width out
    [[ -f $img ]] || die "image not found: ${img:-<none>}"
    shift 2
    if [[ ${1:-} == --after ]]; then
        local hit hy1 hx2
        hit="$(last_hit "$pdf" "${2:-}")"
        read -r page _ hy1 hx2 _ <<<"$hit"
        width="${3:-140}"
        x="$(awk -v v="$hx2" 'BEGIN { print v + 6 }')"
        y="$(awk -v v="$hy1" 'BEGIN { print v - 4 }')"
    else
        (($# >= 4)) || die "usage: image <pdf> <png> <page> <x> <y> <width>"
        page="$1" x="$2" y="$3" width="$4"
    fi
    out="$(dest "$pdf" stamped)"
    annot_out stamp "$pdf" "$out" "$page" "$x" "$y" "$width" "$img" >/dev/null
    done_msg "$out"
}

cmd_redact() {
    need_pdf "${1:-}"
    local pdf="$1" mode="${2:-}" arg="${3:-}" out
    [[ -n $arg ]] || die "usage: redact <pdf> --text TERM | --box PAGE:x1,y1,x2,y2"
    out="$(dest "$pdf" redacted)"
    case "$mode" in
    --text) annot_out redact-text "$pdf" "$out" "$arg" >&2 ;;
    --box) annot_out redact-box "$pdf" "$out" "${arg%%:*}" "${arg#*:}" >&2 ;;
    *) die "redact needs --text or --box" ;;
    esac
    done_msg "$out"
}

# --- forms -------------------------------------------------------------------

cmd_form() {
    local sub="${1:-}"
    shift || true
    need_pdf "${1:-}"
    local pdf="$1" out
    case "$sub" in
    list) pcpu form list "$pdf" ;;
    export)
        out="${OUT:-${pdf%.pdf}.form.json}"
        quiet pcpu form export "$pdf" "$out"
        done_msg "$out"
        ;;
    fill)
        [[ -f ${2:-} ]] || die "usage: form fill <pdf> <data.json>"
        out="$(dest "$pdf" filled)"
        quiet pcpu form fill "$pdf" "$2" "$out"
        done_msg "$out"
        ;;
    flatten) cmd_flatten "$pdf" ;;
    *) die "form: list | export | fill | flatten" ;;
    esac
}

cmd_flatten() {
    need_pdf "${1:-}"
    local out
    out="$(dest "$1" flat)"
    qpdf --generate-appearances --flatten-annotations=all "$1" "$out"
    done_msg "$out"
}

# --- document ----------------------------------------------------------------

cmd_compress() {
    need_pdf "${1:-}"
    local level="${2:-ebook}" out
    case "$level" in
    screen | ebook | printer | prepress) ;;
    *) die "level: screen | ebook | printer | prepress" ;;
    esac
    out="$(dest "$1" small)"
    gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dCompatibilityLevel=1.6 \
        "-dPDFSETTINGS=/$level" -sOutputFile="$out" "$1"
    printf '%s → %s\n' "$(du -h "$1" | cut -f1)" "$(du -h "$out" | cut -f1)" >&2
    done_msg "$out"
}

cmd_optimize() {
    need_pdf "${1:-}"
    local out
    out="$(dest "$1" optimized)"
    qpdf --linearize --object-streams=generate --recompress-flate "$1" "$out"
    printf '%s → %s\n' "$(du -h "$1" | cut -f1)" "$(du -h "$out" | cut -f1)" >&2
    done_msg "$out"
}

cmd_ocr() {
    need_pdf "${1:-}"
    local out
    out="$(dest "$1" ocr)"
    ocrmypdf --skip-text --rotate-pages --deskew -l "$OCR_LANG" "$1" "$out" >&2
    done_msg "$out"
}

cmd_encrypt() {
    need_pdf "${1:-}"
    local pdf="$1" out opts=() upw opw
    shift
    while (($#)); do
        case "$1" in
        --no-print) opts+=(--print=none) ;;
        --no-copy) opts+=(--extract=n) ;;
        --no-modify) opts+=(--modify=none --annotate=n) ;;
        *) die "unknown option: $1" ;;
        esac
        shift
    done
    upw="$(secret DOTS_PDF_PASS "open password (empty = none): ")"
    # the owner password must differ from the open password, otherwise anyone who
    # can open the file can lift the restrictions. Random and discarded unless given.
    opw="${DOTS_PDF_OWNER_PASS:-$(head -c 18 /dev/urandom | base64)}"
    out="$(dest "$pdf" locked)"
    mktmp
    # argument file keeps the passwords out of `ps`
    (
        umask 077
        printf '%s\n' --encrypt "$upw" "$opw" 256 "${opts[@]}" -- >"$TMP/args"
    )
    qpdf "$pdf" "@$TMP/args" "$out"
    done_msg "$out"
}

cmd_decrypt() {
    need_pdf "${1:-}"
    local out pw
    out="$(dest "$1" unlocked)"
    pw="$(secret DOTS_PDF_PASS "password: ")"
    mktmp
    (umask 077 && printf '%s' "$pw" >"$TMP/pw")
    qpdf --password-file="$TMP/pw" --decrypt "$1" "$out"
    done_msg "$out"
}

cmd_meta() {
    need_pdf "${1:-}"
    local pdf="$1" out
    shift
    if (($# == 0)); then
        exiftool -G1 -a -s "$pdf" | grep -E 'PDF|XMP' || true
        return
    fi
    # validate first so a rejected key leaves nothing behind
    local kv a=()
    if [[ $1 != --strip ]]; then
        for kv in "$@"; do
            [[ $kv == *=* ]] || die "expected Key=Value, got: $kv"
            case "${kv%%=*}" in
            Title | Author | Subject | Keywords | Creator | Producer) ;;
            *) die "metadata key must be Title, Author, Subject, Keywords, Creator or Producer" ;;
            esac
            a+=("-${kv%%=*}=${kv#*=}")
        done
    fi
    out="$(dest "$pdf" meta)"
    cp "$pdf" "$out"
    mktmp
    if [[ $1 == --strip ]]; then
        exiftool -q -overwrite_original -all:all= "$out"
    else
        exiftool -q -overwrite_original "${a[@]}" "$out"
    fi
    # exiftool only appends; rewriting drops the old values for real
    qpdf --linearize "$out" "$TMP/clean.pdf"
    mv "$TMP/clean.pdf" "$out"
    done_msg "$out"
}

cmd_bookmarks() {
    local sub="${1:-}"
    shift || true
    need_pdf "${1:-}"
    local pdf="$1" out
    case "$sub" in
    export)
        out="${OUT:-${pdf%.pdf}.bookmarks.json}"
        quiet pcpu bookmarks export "$pdf" "$out"
        done_msg "$out"
        ;;
    import)
        [[ -f ${2:-} ]] || die "usage: bookmarks <pdf> import <bookmarks.json>"
        out="$(dest "$pdf" bookmarked)"
        quiet pcpu bookmarks import "$pdf" "$2" "$out"
        done_msg "$out"
        ;;
    clear)
        out="$(dest "$pdf" nobookmarks)"
        quiet pcpu bookmarks remove "$pdf" "$out"
        done_msg "$out"
        ;;
    *) die "bookmarks: export | import | clear" ;;
    esac
}

cmd_attach() {
    local sub="${1:-}"
    shift || true
    need_pdf "${1:-}"
    local pdf="$1" out
    shift
    case "$sub" in
    list) pcpu attachments list "$pdf" ;;
    add)
        (($# > 0)) || die "attach add <pdf> <files...>"
        out="$(dest "$pdf" attached)"
        cp "$pdf" "$out"
        quiet pcpu attachments add --force "$out" "$@" || {
            rm -f "$out"
            return 1
        }
        done_msg "$out"
        ;;
    extract)
        out="${1:-${pdf%.pdf}.attachments}"
        mkdir -p "$out"
        quiet pcpu attachments extract "$pdf" "$out"
        done_msg "$out"
        ;;
    *) die "attach: add | list | extract" ;;
    esac
}

# --- convert -----------------------------------------------------------------

cmd_to_images() {
    need_pdf "${1:-}"
    local fmt="${2:-png}" dpi="${3:-150}" dir
    dir="${OUT:-${1%.pdf}.pages}"
    mkdir -p "$dir"
    case "$fmt" in
    png) pdftoppm -r "$dpi" -png "$1" "$dir/page" ;;
    jpg | jpeg) pdftoppm -r "$dpi" -jpeg "$1" "$dir/page" ;;
    *) die "format: png | jpg" ;;
    esac
    printf '%s\n' "$dir"
}

cmd_from_images() {
    (($# > 0)) || die "from-images <img>... -o OUT"
    local out="${OUT:-${1%.*}.pdf}"
    [[ ! -e $out || $FORCE -eq 1 ]] || die "already exists: $out (use --force)"
    img2pdf "$@" -o "$out"
    done_msg "$out"
}

cmd_from_office() {
    command -v soffice >/dev/null || die "LibreOffice (soffice) is not installed"
    [[ -f ${1:-} ]] || die "not a file: ${1:-}"
    local src="$1" base made out n=1
    base="${src%.*}"
    if [[ -n $OUT ]]; then
        out="$OUT"
        [[ ! -e $out || $FORCE -eq 1 ]] || die "already exists: $out (use --force)"
    else
        out="$base.pdf"
        while [[ -e $out ]]; do
            n=$((n + 1))
            out="$base-$n.pdf"
        done
    fi
    mktmp
    # convert in a scratch dir, never next to the source: soffice overwrites
    # <name>.pdf there without asking. Its own profile dir too, so a
    # LibreOffice that is already open can't swallow the request.
    soffice -env:UserInstallation="file://$TMP/lo-profile" --headless \
        --convert-to pdf --outdir "$TMP" "$src" >/dev/null
    made="$TMP/$(basename "${src%.*}").pdf"
    [[ -f $made ]] || die "LibreOffice produced no PDF for $src"
    mv -- "$made" "$out"
    done_msg "$out"
}

# --- gui ---------------------------------------------------------------------

cmd_gui() {
    local what="${1:-}" pdf="${2:-}"
    need_pdf "$pdf"
    local bin
    case "$what" in
    view) bin=zathura ;;
    annotate) bin=xournalpp ;;
    arrange) bin=pdfarranger ;;
    edit)
        command -v soffice >/dev/null || die "LibreOffice (soffice) is not installed"
        setsid -f soffice --draw "$pdf" >/dev/null 2>&1
        return
        ;;
    *) die "gui: view | annotate | arrange | edit" ;;
    esac
    command -v "$bin" >/dev/null || die "$bin is not installed"
    setsid -f "$bin" "$pdf" >/dev/null 2>&1
}

# --- dispatch ----------------------------------------------------------------

while (($#)); do
    case "$1" in
    -o | --out)
        [[ -n ${2:-} ]] || die "$1 needs a path"
        OUT="$2"
        shift 2
        ;;
    --force)
        FORCE=1
        shift
        ;;
    --)
        # literal text follows (a search term that happens to be "-o", ...)
        shift
        ARGS+=("$@")
        break
        ;;
    *)
        ARGS+=("$1")
        shift
        ;;
    esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

cmd="${1:-}"
shift || true
case "$cmd" in
info) cmd_info "$@" ;;
text) cmd_text "$@" ;;
grep) cmd_grep "$@" ;;
find) cmd_find "$@" ;;
outline) cmd_outline "$@" ;;
annots) cmd_annots "$@" ;;
images) cmd_images "$@" ;;
render) cmd_render "$@" ;;
diff) cmd_diff "$@" ;;
merge) cmd_merge "$@" ;;
extract) cmd_extract "$@" ;;
delete) cmd_delete "$@" ;;
reorder) cmd_reorder "$@" ;;
rotate) cmd_rotate "$@" ;;
split) cmd_split "$@" ;;
crop) cmd_crop "$@" ;;
number) cmd_number "$@" ;;
watermark) cmd_watermark "$@" ;;
highlight) cmd_mark Highlight "$@" ;;
underline) cmd_mark Underline "$@" ;;
strike) cmd_mark StrikeOut "$@" ;;
squiggly) cmd_mark Squiggly "$@" ;;
note) cmd_note "$@" ;;
text-add | fill) cmd_text_add "$@" ;;
image) cmd_image "$@" ;;
redact) cmd_redact "$@" ;;
form) cmd_form "$@" ;;
flatten) cmd_flatten "$@" ;;
compress) cmd_compress "$@" ;;
optimize) cmd_optimize "$@" ;;
ocr) cmd_ocr "$@" ;;
encrypt) cmd_encrypt "$@" ;;
decrypt) cmd_decrypt "$@" ;;
meta) cmd_meta "$@" ;;
bookmarks) cmd_bookmarks "$@" ;;
attach) cmd_attach "$@" ;;
to-images) cmd_to_images "$@" ;;
from-images) cmd_from_images "$@" ;;
from-office) cmd_from_office "$@" ;;
gui) cmd_gui "$@" ;;
"" | -h | --help | help) usage ;;
*) die "unknown command: $cmd (try: dots-pdf help)" ;;
esac
