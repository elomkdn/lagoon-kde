#!/usr/bin/env python3
"""Variantes translucides des cadres du thème Plasma (panneaux, popups, infobulles).

Plasma prend `translucent/<image>` quand KWin peut flouter derrière, `solid/<image>` pour un
panneau opaque et ses popups, et l'image elle-même sinon : les SVG de plasma-theme/ restent
opaques, et ce script en tire les deux variantes.

Le flou de KWin suit une région en pixels entiers, calculée à partir des pièces mask-* :
sur un coin arrondi, elle fait un escalier, qu'un fond translucide laisserait voir au bord.
Ici, le bord du cadre est un liseré opaque de RIM px, et le masque est rentré de INSET px :
l'escalier de la région (au plus 0,71 px de part et d'autre de la courbe) reste sous le
liseré, l'intérieur est flouté partout où il est translucide, et le bord, dessiné par le SVG,
reste anticrénelé.

usage : build-translucent.py plasma-theme/ dossier-du-thème-installé/
"""
import gzip
import re
import sys
from pathlib import Path

FRAMES = ("widgets/panel-background.svg", "dialogs/background.svgz", "widgets/tooltip.svg")
ALPHA = 0.8      # opacité du fond, à l'intérieur du liseré
RIM = 2.0        # largeur du liseré opaque
INSET = 1.0      # retrait du masque de flou
OVERLAP = 0.5    # le fond passe sous le liseré : pas de jour entre les deux
HIGHLIGHT = "fill:#ffffff;opacity:0.05"   # le liseré clair des popups opaques, élargi au liseré

# sens de chaque coin, depuis le centre de son arrondi : (sx, sy)
CORNERS = {"topleft": (-1, -1), "topright": (1, -1), "bottomleft": (-1, 1), "bottomright": (1, 1)}
EDGES = ("top", "bottom", "left", "right")
PIECE = re.compile(r'<g id="(?P<id>(?:mask-)?(?:top|bottom)?(?:left|right)?|(?:mask-)?center)"'
                   r' (?P<transform>transform="[^"]*")>(?P<body>.*?)</g>')
BOX = re.compile(r'<rect x="0" y="0" width="(?P<w>[\d.]+)" height="(?P<h>[\d.]+)" style="fill:none;stroke:none" />')
FILL = re.compile(r'<path d="[^"]*" style="(?P<style>[^"]*)" class="(?P<cls>ColorScheme-[A-Za-z]+)" />')


def n(x):
    return f"{x:g}"


def quarter(cx, cy, sx, sy, r):
    """Quart de disque de rayon r, centré en (cx, cy), vers le coin (sx, sy)."""
    sweep = 1 if sx * sy > 0 else 0
    return (f"M {n(cx)} {n(cy)} L {n(cx + sx * r)} {n(cy)} "
            f"A {n(r)} {n(r)} 0 0 {sweep} {n(cx)} {n(cy + sy * r)} Z")


def ring(cx, cy, sx, sy, r1, r2):
    """Quart d'anneau entre les rayons r1 < r2."""
    sweep = 1 if sx * sy > 0 else 0
    return (f"M {n(cx + sx * r2)} {n(cy)} A {n(r2)} {n(r2)} 0 0 {sweep} {n(cx)} {n(cy + sy * r2)} "
            f"L {n(cx)} {n(cy + sy * r1)} A {n(r1)} {n(r1)} 0 0 {1 - sweep} {n(cx + sx * r1)} {n(cy)} Z")


def strip(side, w, h, a, b):
    """Bande d'un bord, entre les distances a et b de son côté extérieur."""
    x0, y0, x1, y1 = {"top": (0, a, w, b), "bottom": (0, h - b, w, h - a),
                      "left": (a, 0, b, h), "right": (w - b, 0, w - a, h)}[side]
    return f"M {n(x0)},{n(y0)} H {n(x1)} V {n(y1)} H {n(x0)} Z"


def shapes(name, w, h):
    """(fond, liseré, masque) d'une pièce ; None pour le centre, sans liseré."""
    if name in CORNERS:
        sx, sy = CORNERS[name]
        r = w  # coins carrés, de la taille de l'arrondi
        cx, cy = (w if sx < 0 else 0), (h if sy < 0 else 0)
        return (quarter(cx, cy, sx, sy, r - RIM + OVERLAP), ring(cx, cy, sx, sy, r - RIM, r),
                quarter(cx, cy, sx, sy, r - INSET))
    if name in EDGES:
        depth = h if name in ("top", "bottom") else w
        return (strip(name, w, h, RIM - OVERLAP, depth), strip(name, w, h, 0, RIM),
                strip(name, w, h, INSET, depth))
    full = f"M 0,0 H {n(w)} V {n(h)} H 0 Z"
    return full, None, full


def translucent(svg):
    fills = {}

    def piece(m):
        pid, body = m["id"], m["body"]
        box = BOX.search(body)
        w, h = float(box["w"]), float(box["h"])
        mask = pid.startswith("mask-")
        name = pid.removeprefix("mask-")
        inside, rim, cut = shapes(name, w, h)
        out = [box[0]]
        if mask:
            out.append(f'<path d="{cut}" style="fill:#000000" />')
        else:
            fill = FILL.search(body)
            style = re.sub(r"fill-opacity:[\d.]+;?", "", fill["style"]).rstrip(";")
            fills[name] = fill["cls"]
            out.append(f'<path d="{inside}" style="{style};fill-opacity:{ALPHA:g}" class="{fill["cls"]}" />')
            if rim:
                out.append(f'<path d="{rim}" style="{style};fill-opacity:1" class="{fill["cls"]}" />')
                out.append(f'<path d="{rim}" style="{HIGHLIGHT}" />')
        return f'<g id="{pid}" {m["transform"]}>{"".join(out)}</g>'

    start = svg.index('<g id="rf-pieces">')
    end = svg.index("</g></g>", start) + len("</g></g>")
    pieces, count = PIECE.subn(piece, svg[start:end])
    if count != 18 or len(fills) != 9:
        raise SystemExit(f"pièces inattendues : {count} trouvées, 18 attendues")
    return svg[:start] + pieces + svg[end:]


def read(path):
    return gzip.decompress(path.read_bytes()).decode() if path.suffix == ".svgz" else path.read_text()


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = text.encode()
    path.write_bytes(gzip.compress(data, mtime=0) if path.suffix == ".svgz" else data)


def main(src, dst):
    src, dst = Path(src), Path(dst)
    for frame in FRAMES:
        svg = read(src / frame)
        write(dst / "translucent" / frame, translucent(svg))
        # sans variante solid/, un panneau opaque prendrait celle de Breeze, le thème de repli
        write(dst / "solid" / frame, svg)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__.strip().splitlines()[-1])
    main(*sys.argv[1:])
