.pragma library

// The NixOS logo as block-character art, for the screensaver (ScreensaverFace.qml).
// From fastfetch's built-in "nixos" logo (MIT licence, github.com/fastfetch-cli/fastfetch),
// with the common indent removed.
var lines = [
    "          ▗▄▄▄       ▗▄▄▄▄    ▄▄▄▖",
    "          ▜███▙       ▜███▙  ▟███▛",
    "           ▜███▙       ▜███▙▟███▛",
    "            ▜███▙       ▜██████▛",
    "     ▟█████████████████▙ ▜████▛     ▟▙",
    "    ▟███████████████████▙ ▜███▙    ▟██▙",
    "           ▄▄▄▄▖           ▜███▙  ▟███▛",
    "          ▟███▛             ▜██▛ ▟███▛",
    "         ▟███▛               ▜▛ ▟███▛",
    "▟███████████▛                  ▟██████████▙",
    "▜██████████▛                  ▟███████████▛",
    "      ▟███▛ ▟▙               ▟███▛",
    "     ▟███▛ ▟██▙             ▟███▛",
    "    ▟███▛  ▜███▙           ▝▀▀▀▀",
    "    ▜██▛    ▜███▙ ▜██████████████████▛",
    "     ▜▛     ▟████▙ ▜████████████████▛",
    "           ▟██████▙         ▜███▙",
    "          ▟███▛▜███▙         ▜███▙",
    "         ▟███▛  ▜███▙         ▜███▙",
    "         ▝▀▀▀    ▀▀▀▀▘         ▀▀▀▘"
];

// Block elements as the quarters of the cell they fill (bits: 1 upper-left,
// 2 upper-right, 4 lower-left, 8 lower-right). The screensaver draws them as
// rectangles on a shared pixel grid: font glyphs leave hairline seams.
var quads = {
    "█": 15, "▀": 3, "▄": 12, "▌": 5, "▐": 10,
    "▘": 1, "▝": 2, "▖": 4, "▗": 8, "▚": 9, "▞": 6,
    "▛": 7, "▜": 11, "▙": 13, "▟": 14
};

// every visible character once: {ch, q, r, c, k} with q its quarters and k a
// fixed pseudo-random 0..1 (deterministic, so every screen plays an effect the
// same way)
function cells() {
    var out = [];
    var seed = 7;
    for (var r = 0; r < lines.length; r++) {
        for (var c = 0; c < lines[r].length; c++) {
            seed = (seed * 1103515245 + 12345) % 2147483648;
            var ch = lines[r][c];
            if (ch !== " ")
                out.push({ ch: ch, q: quads[ch] !== undefined ? quads[ch] : 15, r: r, c: c, k: seed / 2147483648 });
        }
    }
    return out;
}

function cols() {
    var n = 0;
    for (var i = 0; i < lines.length; i++) n = Math.max(n, lines[i].length);
    return n;
}
