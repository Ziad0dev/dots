.pragma library

// WANTED is the single source of truth for which raw colors.sh keys map
// onto this shell's semantic slots. Legacy NixOS colorN keys intentionally
// come first so mixed files keep the old values stable.
const WANTED = [
    { target: "paper",      keys: ["background", "bg"] },
    { target: "ink",        keys: ["foreground", "fg"] },
    { target: "color01",    keys: ["color1", "red"] },
    { target: "color02",    keys: ["color2", "green"] },
    { target: "color03",    keys: ["color3", "yellow"] },
    { target: "color04",    keys: ["color4", "blue"] },
    { target: "color05",    keys: ["color5", "magenta"] },
    { target: "color06",    keys: ["color6", "cyan"] },
    { target: "color07",    keys: ["color7", "bright_fg", "light_fg"] },
    { target: "sumi",       keys: ["color8", "muted", "dark_fg"] },
    { target: "accentHint", keys: ["accent"] },
];

const LINE = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;

function parseAll(text) {
    const out = {};
    if (!text) return out;
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const m = lines[i].match(LINE);
        if (m) out[m[1].toLowerCase()] = m[2];
    }
    return out;
}

function mapKeys(raw) {
    const out = {};
    if (!raw) return out;
    for (let i = 0; i < WANTED.length; i++) {
        const group = WANTED[i];
        for (let j = 0; j < group.keys.length; j++) {
            const value = raw[group.keys[j]];
            if (validColor(value)) {
                out[group.target] = value;
                break;
            }
        }
    }
    return out;
}

// Muted text comes from color8, a terminal's "bright black", which many
// palettes keep barely above the background (oled: #3a3a3a on black, 1.85:1).
// Lift it toward the foreground until it is readable, keeping its hue.
const MIN_MUTED_CONTRAST = 4.5;

function parse(text) {
    const out = mapKeys(parseAll(text));
    if (out.sumi && out.paper && out.ink)
        out.sumi = readable(out.sumi, out.paper, out.ink, MIN_MUTED_CONTRAST);
    return out;
}

function hexRgb(h) {
    return [1, 3, 5].map(function (i) { return parseInt(h.substr(i, 2), 16) / 255; });
}

function rgbHex(c) {
    return "#" + c.map(function (v) {
        return Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
    }).join("");
}

// WCAG relative luminance and contrast ratio
function luminance(c) {
    const f = function (v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]);
}

function contrast(a, b) {
    const la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

// fg mixed toward `toward` in 5% steps until it reaches `min` against bg
function readable(fg, bg, toward, min) {
    const f = hexRgb(fg), b = hexRgb(bg), t = hexRgb(toward);
    for (let k = 0; k <= 20; k++) {
        const m = k / 20;
        const c = f.map(function (v, i) { return v + (t[i] - v) * m; });
        if (contrast(c, b) >= min) return rgbHex(c);
    }
    return toward;
}

function validColor(value) {
    return typeof value === "string" && /^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(value);
}

function setColor(theme, key, value) {
    if (validColor(value)) theme[key] = value;
}

// Write a parsed palette onto a Theme.qml instance. Missing slots are left
// at their current value so a partial or malformed palette never blanks the
// live theme. NixOS colors.sh values used by this shell are #RRGGBB; accept
// #RRGGBBAA too for forward-compatible alpha colours.
function apply(theme, palette) {
    if (!palette) return;
    setColor(theme, "paper",      palette.paper);
    setColor(theme, "ink",        palette.ink);
    setColor(theme, "sumi",       palette.sumi);
    setColor(theme, "color01",    palette.color01);
    setColor(theme, "color02",    palette.color02);
    setColor(theme, "color03",    palette.color03);
    setColor(theme, "color04",    palette.color04);
    setColor(theme, "color05",    palette.color05);
    setColor(theme, "color06",    palette.color06);
    setColor(theme, "color07",    palette.color07);
    setColor(theme, "accentHint", palette.accentHint);
}
