#!/usr/bin/env python3
"""Fond d'écran Lagoon : logo CachyOS au centre, vagues en papier
découpé dans deux coins opposés, aux couleurs Catppuccin Mocha.

Image vectorielle générée pour n'importe quelle taille, puis rendue en PNG.

usage : make-wallpaper.py <logo.svg> <sortie.png> <largeur> <hauteur> [--no-logo]
        make-wallpaper.py <logo.svg> <sortie.svg> --logo-only [--no-bubbles]
  --no-logo   : sans le logo (fond du splash, qui affiche le sien)
  --logo-only : le logo seul, en SVG (pour le splash)
  --no-bubbles : le C sans ses trois bulles (le splash les anime)
"""
import math
import re
import subprocess
import sys
import tempfile
from pathlib import Path

CRUST, MANTLE, BASE, TEAL = "#11111b", "#181825", "#1e1e2e", "#94e2d5"
# taille du logo : côté de son carré, en part du petit côté de l'écran
LOGO_SCALE = 0.26
# vagues, de la plus grande (sombre) à la plus petite (claire) : part de teal mêlé au fond
LAYERS = [0.16, 0.28, 0.42, 0.60, 0.88]


def mix(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def smooth_path(points):
    """Courbe lisse (Catmull-Rom -> Bézier) passant par les points."""
    d = f"M {points[0][0]:.1f},{points[0][1]:.1f}"
    for i in range(len(points) - 1):
        p0 = points[max(i - 1, 0)]
        p1, p2 = points[i], points[i + 1]
        p3 = points[min(i + 2, len(points) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C {c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}"
    return d


def wave(w, h, rx, ry, phase):
    """Vague dans le coin bas-gauche : bord ondulé d'un quart d'ellipse de rayons rx, ry."""
    pts = []
    n = 60
    for i in range(n + 1):
        t = i / n * math.pi / 2  # 0 : bord gauche, pi/2 : bord bas
        k = 1 + 0.09 * math.sin(3 * t * 2 + phase) + 0.04 * math.sin(7 * t + phase * 1.7)
        pts.append((rx * math.sin(t) * k, h - ry * math.cos(t) * k))
    pts[0] = (0, pts[0][1])
    pts[-1] = (pts[-1][0], h)
    # fermée hors de l'image : le contour ne doit pas longer les bords de l'écran
    out = 0.05 * min(w, h)
    return smooth_path(pts) + f" L {pts[-1][0]:.1f},{h + out:.1f} L {-out:.1f},{h + out:.1f} L {-out:.1f},{pts[0][1]:.1f} Z"


def logo_paths(logo_svg):
    """Tracés du logo, tous remplis d'une même couleur (silhouette)."""
    s = Path(logo_svg).read_text()
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', s).group(1).split()]
    # contenu du logo, structure et transformations comprises, sans définitions ni métadonnées
    body = re.search(r"<svg\b[^>]*>(.*)</svg>", s, re.S).group(1)
    body = re.sub(r"<(defs|metadata)\b.*?</\1>", "", body, flags=re.S)
    body = re.sub(r"<sodipodi:namedview\b.*?(/>|</sodipodi:namedview>)", "", body, flags=re.S)
    # calques d'ombrage (dégradés vers le transparent) : ils débordent un peu des facettes,
    # invisible en couleurs mais visible en silhouette unie (petite corne en haut du C)
    body = re.sub(r"<(path|circle|ellipse|rect)\b[^>]*?fill:url\([^>]*?/>", "", body, flags=re.S)
    # plus aucune couleur propre : tout hérite du remplissage du groupe
    body = re.sub(r'\s(style|fill|stroke|class|filter|opacity|fill-opacity)="[^"]*"', "", body)
    body = re.sub(r'\s(inkscape|sodipodi):[a-zA-Z-]+="[^"]*"', "", body)
    return vb, body


def svg(w, h, logo_svg, with_logo=True):
    s = min(w, h)
    layers = []
    for corner in ("bl", "tr"):
        transform = "" if corner == "bl" else f' transform="rotate(180 {w / 2} {h / 2})"'
        group = []
        for i, t in enumerate(LAYERS):
            scale = 1 - i * 0.16
            rx, ry = 0.36 * w * scale, 0.52 * h * scale
            outline = f' stroke="{mix(BASE, TEAL, 0.75)}" stroke-width="{s * 0.0012:.1f}"' if i == 0 else ""
            group.append(f'<path d="{wave(w, h, rx, ry, 0.6 * i + (0 if corner == "bl" else 1.3))}" '
                         f'fill="{mix(BASE, TEAL, t)}"{outline} filter="url(#paper)"/>')
        layers.append(f"<g{transform}>" + "".join(group) + "</g>")

    if not with_logo:
        logo = ""
    else:
        logo = draw_logo(logo_svg, w, h, s)
    return document(w, h, s, layers, logo)


def draw_logo(logo_svg, w, h, s):
    vb, paths = logo_paths(logo_svg)
    size = s * LOGO_SCALE
    lx, ly = (w - size) / 2, (h - size) / 2
    k = size / vb[2]
    return (f'<g transform="translate({lx:.1f},{ly:.1f}) scale({k:.4f}) translate({-vb[0]},{-vb[1]})" '
            f'fill="{TEAL}" stroke="none">{paths}</g>')


def document(w, h, s, layers, logo):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs>
  <radialGradient id="bg" cx="{w * 0.5}" cy="{h * 0.48}" r="{max(w, h) * 0.75}" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="{BASE}"/><stop offset="0.6" stop-color="{MANTLE}"/><stop offset="1" stop-color="{CRUST}"/>
  </radialGradient>
  <filter id="paper" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="0" stdDeviation="{s * 0.012:.1f}" flood-color="#000000" flood-opacity="0.45"/>
  </filter>
</defs>
<rect width="{w}" height="{h}" fill="url(#bg)"/>
{"".join(layers)}
{logo}
</svg>'''


def logo_only(logo_svg, bubbles=True):
    vb, paths = logo_paths(logo_svg)
    if not bubbles:
        paths = re.sub(r"<circle\b[^>]*?/>", "", paths, flags=re.S)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{" ".join(f"{v:g}" for v in vb)}" '
            f'width="{vb[2]:g}" height="{vb[3]:g}"><g fill="{TEAL}" stroke="none">{paths}</g></svg>')


def main():
    if "--logo-only" in sys.argv:
        Path(sys.argv[2]).write_text(logo_only(sys.argv[1], bubbles="--no-bubbles" not in sys.argv))
        return
    logo, out, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg(w, h, logo, with_logo="--no-logo" not in sys.argv[5:]))
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", out, f.name], check=True)
    Path(f.name).unlink()


if __name__ == "__main__":
    main()
