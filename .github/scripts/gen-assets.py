#!/usr/bin/env python3
import argparse
import colorsys
import re
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
FONT = "JetBrains Mono, ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
LINE = re.compile(r'^([A-Za-z0-9_]+)="?(#[0-9a-fA-F]{6})"?\s*$')


def palette(path):
    out = {}
    for line in path.read_text().splitlines():
        m = LINE.match(line.strip())
        if m:
            out[m.group(1)] = m.group(2).lower()
    return out


def themes(themes_dir):
    found = []
    for d in sorted(p for p in themes_dir.iterdir() if p.is_dir() and not p.name.startswith("_")):
        for name in ("colors.sh", "theme.sh"):
            f = d / name
            if f.is_file():
                pal = palette(f)
                if "background" in pal and "foreground" in pal:
                    found.append((d.name, pal))
                break
    if not found:
        raise SystemExit(f"no themes found under {themes_dir}")
    return found


def hue(hex_):
    r, g, b = (int(hex_[i : i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return (s < 0.15, h, l)


def mix(a, b, t):
    ca = [int(a[i : i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i : i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def banner(ts, base):
    w, h, stripe = 1200, 300, 10
    faint = mix(base["base03"], base["base04"], 0.3)
    accents = sorted({p.get("accent", p["foreground"]) for _, p in ts}, key=hue)
    seg = w / len(accents)
    bars = "".join(
        f'<rect x="{i * seg:.2f}" y="{h - stripe}" width="{seg + 0.6:.2f}" height="{stripe}" fill="{c}"/>'
        for i, c in enumerate(accents)
    )
    dots = "".join(
        f'<circle cx="{404 + i * 34}" cy="150" r="11" fill="{base[k]}"/>'
        for i, k in enumerate(("color1", "color4", "color5"))
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img" aria-label="dots">
<defs><clipPath id="c"><rect width="{w}" height="{h}" rx="14"/></clipPath></defs>
<g clip-path="url(#c)">
<rect width="{w}" height="{h}" fill="{base['background']}"/>
<text x="72" y="170" font-family="{FONT}" font-size="128" font-weight="800" fill="{base['foreground']}">dots</text>
{dots}
<text x="76" y="218" font-family="{FONT}" font-size="26" fill="{base['base04']}">NixOS · Hyprland · Quickshell — one flake, {len(ts)} themes</text>
<text x="76" y="252" font-family="{FONT}" font-size="18" fill="{faint}">nixos · nix-darwin · home-manager · templates · tool flakes</text>
{bars}
</g>
</svg>
"""


def gallery(ts, cols=4):
    cw, ch, gap, pad = 224, 62, 12, 4
    rows = -(-len(ts) // cols)
    w = pad * 2 + cols * cw + (cols - 1) * gap
    h = pad * 2 + rows * ch + (rows - 1) * gap
    cards = []
    for i, (name, p) in enumerate(ts):
        x = pad + (i % cols) * (cw + gap)
        y = pad + (i // cols) * (ch + gap)
        edge = p.get("base02", p.get("color8", p["foreground"]))
        accent = p.get("accent", p["foreground"])
        sw = "".join(
            f'<rect x="{x + 16 + j * 26}" y="{y + 36}" width="20" height="12" rx="3" fill="{p[k]}"/>'
            for j, k in enumerate(("color1", "color2", "color3", "color4", "color5", "color6", "accent"))
            if k in p
        )
        cards.append(
            f'<g><rect x="{x}" y="{y}" width="{cw}" height="{ch}" rx="8" fill="{p["background"]}" stroke="{edge}"/>'
            f'<rect x="{x}" y="{y + 12}" width="3" height="{ch - 24}" rx="1.5" fill="{accent}"/>'
            f'<text x="{x + 16}" y="{y + 24}" font-family="{FONT}" font-size="13" font-weight="700" fill="{p["foreground"]}">{escape(name)}</text>'
            f"{sw}</g>"
        )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img" aria-label="{len(ts)} themes">\n'
        + "\n".join(cards)
        + "\n</svg>\n"
    )


def main():
    ap = argparse.ArgumentParser(description="Render README assets from config/themes.")
    ap.add_argument("--themes", type=Path, default=ROOT / "config/themes")
    ap.add_argument("--out", type=Path, default=ROOT / ".github/assets")
    ap.add_argument("--base", default="oxocarbon", help="theme used for the banner")
    a = ap.parse_args()

    ts = themes(a.themes)
    base = dict(ts)[a.base]
    a.out.mkdir(parents=True, exist_ok=True)
    (a.out / "banner.svg").write_text(banner(ts, base))
    (a.out / "themes.svg").write_text(gallery(ts))
    print(f"{len(ts)} themes -> {a.out}/banner.svg, {a.out}/themes.svg")


if __name__ == "__main__":
    main()
