#!/usr/bin/env bash
# dots-pdfsign — cryptographic PDF signatures (PAdES / PKCS#7) from the terminal.
# Local certificate, no Adobe. Signatures are appended as incremental updates,
# so a document can carry several of them and earlier ones stay valid.
set -o errexit -o nounset -o pipefail

STATE="${XDG_DATA_HOME:-$HOME/.local/share}/dots/pdfsign"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/dots"
CERT="$STATE/signing.p12"
TRUST="$STATE/cert.pem"
PASS="$CONF/pdfsign.pass"
SIGIMG="$STATE/signature.png"
ANNOT_JS="${DOTS_PDF_JS:-$(dirname "$(readlink -f "$0")")/dots-pdf-annot.js}"

TMP=""
cleanup() { [[ -z $TMP ]] || rm -rf "$TMP"; }
trap cleanup EXIT

BOX_W=240
BOX_H=64
MARGIN=36

die() {
    printf 'dots-pdfsign: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
usage: dots-pdfsign <command>

  init [CN] [email]      create a local self-signed signing certificate (once)
  import <p12> [--store-pass]
                         use a real certificate (.p12/.pfx) instead; the
                         passphrase is only saved with --store-pass
  image <png|jpg|->      set the handwritten-signature image shown in visible
                         signatures (white is made transparent); `-` removes it
  status                 show the active certificate and signature image
  cert                   print the path of the public certificate to hand out
  fields <pdf>           list signature fields (and who has signed)
  sign [opts] <pdf>      sign; writes <pdf>.signed.pdf, then .signed-2.pdf, ...
                         (never the original)
  verify <pdf>           validate every signature in the file

sign options
  --field NAME           fill an existing (empty) signature field
  --page N               page for a visible signature (default: last)
  --box x1,y1,x2,y2      visible box in PDF points, origin bottom-left
  --where PRESET         bottom-right | bottom-left | bottom-center |
                         top-right | top-left | top-center
  --at TEXT              visible box placed right after the last occurrence of
                         TEXT, e.g. --at "Signature:"
  --image PNG            appearance image for this signature only
  --no-image             text-only appearance even if an image is configured
  --reason TEXT          reason (default: "Signed")
  --location TEXT        location
  --contact TEXT         contact info
  --name TEXT            signer name override
  --certify              certification signature (no further changes allowed)
  --pades                PAdES baseline signature
  --timestamp-url URL    RFC 3161 timestamp authority (network access)
  --out PATH             output path

Without --field/--page/--box/--where/--at the signature is invisible, or fills
the first empty signature field if the document already has one.

Cert:   $XDG_DATA_HOME/dots/pdfsign/signing.p12
Pass:   $XDG_CONFIG_HOME/dots/pdfsign.pass   (or env DOTS_PDFSIGN_PASS)
Note:   a self-signed certificate proves integrity, not identity: recipients
        see "unknown signer" until they trust `dots-pdfsign cert`.
EOF
}

need_cert() {
    [[ -f $CERT ]] || die "no certificate yet — run: dots-pdfsign init (or import)"
}

need_pdf() {
    [[ -n ${1:-} ]] || die "no PDF given"
    [[ -f $1 ]] || die "not a file: $1"
}

# page size in points: "W H" for page $2 of $1
page_size() {
    pdfinfo -f "$2" -l "$2" "$1" |
        awk -v p="$2" '$1 == "Page" && $2 == p && $3 == "size:" { print $4, $6; exit }'
}

page_count() {
    pdfinfo "$1" | awk '$1 == "Pages:" { print $2 }'
}

cmd_init() {
    [[ -f $CERT ]] && die "already initialised at $CERT — move it aside first"

    local cn="${1:-$(id -un)}"
    local mail="${2:-$(id -un)@localhost}"
    mkdir -p "$STATE" "$CONF"
    chmod 700 "$STATE" "$CONF"

    TMP="$(mktemp -d)"
    local tmp="$TMP"
    local pass
    pass="$(head -c 32 /dev/urandom | base64 | tr -d '\n=')"
    (umask 077 && printf '%s' "$pass" >"$PASS")

    openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
        -keyout "$tmp/key.pem" -out "$TRUST" \
        -subj "/CN=$cn/emailAddress=$mail" \
        -addext "keyUsage=critical,digitalSignature,nonRepudiation" 2>/dev/null
    chmod 644 "$TRUST"

    openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$TRUST" \
        -name "$cn" -out "$CERT" -passout "file:$PASS"
    chmod 600 "$CERT"

    printf 'cert: %s\npublic: %s\npass: %s\n' "$CERT" "$TRUST" "$PASS"
}

cmd_import() {
    local src="" store=0
    while (($#)); do
        case "$1" in
        --store-pass) store=1 ;;
        -*) die "unknown option: $1" ;;
        *) src="$1" ;;
        esac
        shift
    done
    [[ -f $src ]] || die "usage: dots-pdfsign import <file.p12> [--store-pass]"
    [[ ! -f $CERT ]] || die "a certificate is already installed ($CERT) — move it aside first"

    mkdir -p "$STATE" "$CONF"
    chmod 700 "$STATE" "$CONF"

    local pass
    read -rsp "passphrase for $src: " pass
    printf '\n'
    printf '%s' "$pass" | openssl pkcs12 -in "$src" -nokeys -passin stdin >/dev/null 2>&1 ||
        die "wrong passphrase or not a PKCS#12 file"

    # public half first: if it can't be extracted nothing is installed, so a
    # retry isn't blocked by a half-imported certificate
    printf '%s' "$pass" | openssl pkcs12 -in "$src" -nokeys -clcerts -passin stdin 2>/dev/null |
        openssl x509 -out "$TRUST.tmp" || {
        rm -f "$TRUST.tmp"
        die "could not read the certificate out of $src"
    }
    mv -f "$TRUST.tmp" "$TRUST"
    chmod 644 "$TRUST"
    install -m 600 "$src" "$CERT"
    rm -f "$PASS"
    if ((store)); then
        (umask 077 && printf '%s' "$pass" >"$PASS")
        printf 'passphrase stored in %s (plaintext, mode 600)\n' "$PASS"
    else
        printf 'passphrase not stored: you will be asked each time (or set DOTS_PDFSIGN_PASS)\n'
    fi
    printf 'imported %s\n' "$CERT"
}

cmd_image() {
    local src="${1:-}"
    [[ -n $src ]] || die "usage: dots-pdfsign image <file|->"
    mkdir -p "$STATE"
    if [[ $src == - ]]; then
        rm -f "$SIGIMG"
        printf 'signature image removed\n'
        return
    fi
    [[ -f $src ]] || die "not a file: $src"
    magick "$src" -fuzz 18% -transparent white -trim +repage "$SIGIMG"
    printf 'signature image: %s\n' "$SIGIMG"
}

cmd_status() {
    if [[ -f $CERT ]]; then
        printf 'certificate: %s\n' "$CERT"
        if [[ -f $TRUST ]]; then
            openssl x509 -in "$TRUST" -noout -subject -enddate -fingerprint -sha256
        fi
    else
        printf 'certificate: none (run: dots-pdfsign init)\n'
    fi
    if [[ -f $SIGIMG ]]; then printf 'image: %s\n' "$SIGIMG"; else printf 'image: none\n'; fi
}

cmd_cert() {
    [[ -f $TRUST ]] || die "no public certificate on disk"
    printf '%s\n' "$TRUST"
}

cmd_fields() {
    need_pdf "${1:-}"
    pyhanko sign list "$1"
}

# first empty signature field in the document, if any (pyhanko prints NAME:EMPTY)
empty_field() {
    pyhanko sign list "$1" 2>/dev/null | awk '/:EMPTY$/ { sub(/:EMPTY$/, ""); print; exit }'
}

# print "PAGE/x1,y1,x2,y2" for a preset on a given page
preset_box() {
    local pdf="$1" page="$2" where="$3" w h x1 y1
    read -r w h < <(page_size "$pdf" "$page")
    [[ -n ${w:-} ]] || die "cannot read page size of page $page"
    case "$where" in
    *-right) x1=$(awk -v w="$w" -v bw="$BOX_W" -v m="$MARGIN" 'BEGIN { print w - m - bw }') ;;
    *-left) x1=$MARGIN ;;
    *-center) x1=$(awk -v w="$w" -v bw="$BOX_W" 'BEGIN { print (w - bw) / 2 }') ;;
    *) die "unknown preset: $where" ;;
    esac
    case "$where" in
    top-*) y1=$(awk -v h="$h" -v bh="$BOX_H" -v m="$MARGIN" 'BEGIN { print h - m - bh }') ;;
    bottom-*) y1=$MARGIN ;;
    *) die "unknown preset: $where" ;;
    esac
    awk -v p="$page" -v x="$x1" -v y="$y1" -v bw="$BOX_W" -v bh="$BOX_H" \
        'BEGIN { printf "%d/%.0f,%.0f,%.0f,%.0f\n", p, x, y, x + bw, y + bh }'
}

# print "PAGE/x1,y1,x2,y2" for a box right after the last occurrence of TEXT
text_box() {
    local pdf="$1" text="$2" hit page y1 x2 w h
    hit="$(mutool run "$ANNOT_JS" find "$pdf" - "$text" | tail -n 1)"
    [[ -n $hit ]] || die "text not found: $text"
    read -r page _ y1 x2 _ <<<"$hit"
    read -r w h < <(page_size "$pdf" "$page")
    [[ -n ${w:-} ]] || die "cannot read page size of page $page"
    awk -v p="$page" -v hx="$x2" -v hy="$y1" -v w="$w" -v bw="$BOX_W" -v bh="$BOX_H" 'BEGIN {
        x = hx + 8; y = hy - 3
        if (x + bw > w - 12) x = w - 12 - bw
        if (y < 12) y = 12
        printf "%d/%.0f,%.0f,%.0f,%.0f\n", p, x, y, x + bw, y + bh
    }'
}

write_style() {
    local cfg="$1" image="$2" text="$3"
    {
        printf 'stamp-styles:\n  dots:\n    type: text\n    border-width: 1\n'
        printf '    text-box-style:\n      font-size: 7\n'
        printf '    stamp-text: |-\n'
        while IFS= read -r line; do printf '      %s\n' "$line"; done <<<"$text"
        if [[ -n $image ]]; then
            # image fills the top, the two text lines sit underneath it
            case "$image" in
        *[\"\\$'\n']*) die "image path may not contain quotes, backslashes or newlines: $image" ;;
        esac
        printf '    background: "%s"\n' "$image"
            printf '    background-opacity: 1\n'
            printf '    background-layout:\n      x-align: mid\n      y-align: top\n'
            printf '      margins: {left: 6, right: 6, top: 4, bottom: 22}\n'
            printf '    inner-content-layout:\n      x-align: left\n      y-align: bottom\n'
            printf '      margins: {left: 4, right: 4, top: 2, bottom: 3}\n'
        fi
    } >"$cfg"
}

cmd_sign() {
    local field="" page="" box="" where="" at="" image="" out=""
    [[ ! -f $SIGIMG ]] || image="$SIGIMG"
    local reason="Signed" location="" contact="" name="" certify=0 pades=0 tsa=""
    while (($#)); do
        case "$1" in
        --field) field="$2"; shift 2 ;;
        --page) page="$2"; shift 2 ;;
        --box) box="$2"; shift 2 ;;
        --where) where="$2"; shift 2 ;;
        --at) at="$2"; shift 2 ;;
        --image) image="$2"; shift 2 ;;
        --no-image) image=""; shift ;;
        --out) out="$2"; shift 2 ;;
        --reason) reason="$2"; shift 2 ;;
        --location) location="$2"; shift 2 ;;
        --contact) contact="$2"; shift 2 ;;
        --name) name="$2"; shift 2 ;;
        --certify) certify=1; shift ;;
        --pades) pades=1; shift ;;
        --timestamp-url) tsa="$2"; shift 2 ;;
        -*) die "unknown option: $1" ;;
        *) break ;;
        esac
    done

    local pdf="${1:-}"
    need_pdf "$pdf"
    need_cert
    [[ -z $image || -f $image ]] || die "image not found: $image"

    if [[ -z $out ]]; then
        # signing again gives x.signed-2.pdf, not x.signed.signed.pdf
        local base="${pdf%.pdf}" n=1
        if [[ $base =~ ^(.*)\.signed(-[0-9]+)?$ ]]; then base="${BASH_REMATCH[1]}"; fi
        out="$base.signed.pdf"
        while [[ -e $out ]]; do
            n=$((n + 1))
            out="$base.signed-$n.pdf"
        done
    fi
    [[ $out != "$pdf" ]] || die "refusing to overwrite the original"
    [[ ! -e $out ]] || die "already exists: $out"

    # where does the signature go?
    local fieldspec="" visible=0 fname
    fname="Sig-$(date +%s)"
    if [[ -n $field ]]; then
        fieldspec="$field"
        visible=1
    elif [[ -n $box ]]; then
        [[ -n $page ]] || page="$(page_count "$pdf")"
        fieldspec="$page/$box/$fname"
        visible=1
    elif [[ -n $at ]]; then
        fieldspec="$(text_box "$pdf" "$at")"
        fieldspec="$fieldspec/$fname"
        visible=1
    elif [[ -n $where || -n $page ]]; then
        [[ -n $page ]] || page="$(page_count "$pdf")"
        fieldspec="$(preset_box "$pdf" "$page" "${where:-bottom-right}")"
        fieldspec="$fieldspec/$fname"
        visible=1
    else
        local empty
        empty="$(empty_field "$pdf" || true)"
        if [[ -n $empty ]]; then
            fieldspec="$empty"
            visible=1
        else
            fieldspec="$fname"
        fi
    fi

    TMP="$(mktemp -d)"
    local tmp="$TMP"

    local args=(--config "$tmp/pyhanko.yml" sign addsig --field "$fieldspec" --reason "$reason")
    [[ -n $location ]] && args+=(--location "$location")
    [[ -n $contact ]] && args+=(--contact-info "$contact")
    [[ -n $name ]] && args+=(--name "$name")
    ((certify)) && args+=(--certify)
    ((pades)) && args+=(--use-pades)
    [[ -n $tsa ]] && args+=(--timestamp-url "$tsa")
    if ((visible)); then
        write_style "$tmp/pyhanko.yml" "$image" $'Digitally signed by %(signer)s\n%(ts)s'
        args+=(--style-name dots)
    else
        printf '{}\n' >"$tmp/pyhanko.yml"
    fi

    # the passphrase never goes on the command line
    local pass_in=()
    if [[ -n ${DOTS_PDFSIGN_PASS:-} ]]; then
        (umask 077 && printf '%s' "$DOTS_PDFSIGN_PASS" >"$tmp/pass")
        pass_in=(--passfile "$tmp/pass")
    elif [[ -f $PASS ]]; then
        pass_in=(--passfile "$PASS")
    elif [[ -t 0 ]]; then
        local pw
        read -rsp "certificate passphrase: " pw
        printf '\n'
        (umask 077 && printf '%s' "$pw" >"$tmp/pass")
        pass_in=(--passfile "$tmp/pass")
    else
        die "no passphrase: set DOTS_PDFSIGN_PASS or run from a terminal"
    fi

    local rc=0
    pyhanko "${args[@]}" pkcs12 "${pass_in[@]}" "$pdf" "$out" "$CERT" >&2 || rc=$?
    if ((rc != 0)); then
        # a half-written .signed.pdf looks like a real one; don't leave it
        rm -f "$out"
        exit "$rc"
    fi
    printf '%s\n' "$out"
}

cmd_verify() {
    need_pdf "${1:-}"
    local args=(sign validate --pretty-print --no-revocation-check)
    [[ -f $TRUST ]] && args+=(--trust "$TRUST")
    pyhanko "${args[@]}" "$1"
}

case "${1:-}" in
init) shift; cmd_init "$@" ;;
import) shift; cmd_import "$@" ;;
image) shift; cmd_image "$@" ;;
status) cmd_status ;;
cert) cmd_cert ;;
fields) shift; cmd_fields "$@" ;;
sign) shift; cmd_sign "$@" ;;
verify) shift; cmd_verify "$@" ;;
"" | -h | --help | help) usage ;;
*) die "unknown command: $1" ;;
esac
