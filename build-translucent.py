#!/usr/bin/env python3
"""Variantes translucides des cadres du thème Plasma (panneaux, popups, infobulles).

Plasma prend `translucent/<image>` quand KWin peut flouter derrière, `solid/<image>` pour un
panneau opaque et ses popups, et l'image elle-même sinon : les SVG de plasma-theme/ restent
opaques, et ce script en tire les deux variantes.

Le flou de KWin suit une région en pixels entiers, tirée des pièces mask-* de l'image
elle-même, pas de sa variante translucent/ : ce script les remplace dans les trois. KSvg met
dans la région tout pixel que le masque touche, même à peine, et KWin floute chacun en
entier. Sur le bord anticrénelé d'un coin, un pixel flouté montre le fond flouté jusque dans
sa part hors du cadre (un bord clair quand le fond est clair juste dessous), un pixel non
flouté montre le fond net jusque dans sa part dans le cadre (un escalier). Le masque des
coins ne prend donc que les pixels que l'arrondi couvre (presque) en entier : tous ceux-là
sont floutés, et les pixels du bord, sans flou, se fondent dans ce qui est vraiment autour,
comme un bord anticrénelé ordinaire. Flouter aussi les pixels couverts aux trois quarts
rallume des points clairs le long de l'arrondi. Pas de liseré.

Les coins sont alignés sur les pixels à l'échelle 1 ; à une autre échelle, le masque reste
dans l'arrondi, plus en retrait.

usage : build-translucent.py plasma-theme/ dossier-du-thème-installé/
"""
import gzip
import re
import sys
from pathlib import Path

FRAMES = ("widgets/panel-background.svg", "dialogs/background.svgz", "widgets/tooltip.svg")
ALPHA = 0.75     # opacité du fond : le texte garde 5:1 sur un fond blanc
GAP = 0.02       # retrait des pixels du masque des coins
COVER = 0.95     # un pixel couvert à 95 % compte comme plein : l'anticrénelage le peint presque plein

# sens de chaque coin, depuis le centre de son arrondi : (sx, sy)
CORNERS = {"topleft": (-1, -1), "topright": (1, -1), "bottomleft": (-1, 1), "bottomright": (1, 1)}
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


def coverage(cx, cy, i, j, r, k=16):
    """Part du pixel (i, j) dans le disque de rayon r centré en (cx, cy), sur k x k points."""
    inside = sum((i + (a + 0.5) / k - cx) ** 2 + (j + (b + 0.5) / k - cy) ** 2 <= r * r
                 for a in range(k) for b in range(k))
    return inside / (k * k)


def covered(cx, cy, w, h, r):
    """Les pixels de la pièce que le quart de disque couvre au moins à COVER, un rectangle par
    ligne, rentrés de GAP pour que KSvg ne compte pas leurs voisins."""
    rows = []
    for j in range(int(h)):
        xs = [i for i in range(int(w)) if coverage(cx, cy, i, j, r) >= COVER]
        if xs:
            x0, x1 = min(xs) + GAP, max(xs) + 1 - GAP
            rows.append(f"M {n(x0)},{n(j + GAP)} H {n(x1)} V {n(j + 1 - GAP)} H {n(x0)} Z")
    return " ".join(rows)


def shapes(name, w, h):
    """(fond, masque) d'une pièce."""
    if name in CORNERS:
        sx, sy = CORNERS[name]
        cx, cy = (w if sx < 0 else 0), (h if sy < 0 else 0)
        # coins carrés, de la taille de l'arrondi
        return quarter(cx, cy, sx, sy, w), covered(cx, cy, w, h, w)
    full = f"M 0,0 H {n(w)} V {n(h)} H 0 Z"
    return full, full


def frame(svg, alpha):
    """Le cadre avec le masque des coins aux seuls pixels pleins, et son fond à l'opacité alpha
    (None : le fond tel quel)."""
    fills = {}

    def piece(m):
        pid, body = m["id"], m["body"]
        box = BOX.search(body)
        w, h = float(box["w"]), float(box["h"])
        mask = pid.startswith("mask-")
        name = pid.removeprefix("mask-")
        d, cut = shapes(name, w, h)
        out = [box[0]]
        if mask:
            out.append(f'<path d="{cut}" style="fill:#000000" />')
        else:
            fill = FILL.search(body)
            fills[name] = fill["cls"]
            if alpha is None:
                return m[0]
            style = re.sub(r"fill-opacity:[\d.]+;?", "", fill["style"]).rstrip(";")
            out.append(f'<path d="{d}" style="{style};fill-opacity:{alpha:g}" class="{fill["cls"]}" />')
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
    for path in FRAMES:
        svg = read(src / path)
        write(dst / "translucent" / path, frame(svg, ALPHA))
        # Plasma prend la région de flou dans l'image elle-même, même quand il peint translucent/
        write(dst / path, frame(svg, None))
        # sans variante solid/, un panneau opaque prendrait celle de Breeze, le thème de repli
        write(dst / "solid" / path, frame(svg, None))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__.strip().splitlines()[-1])
    main(*sys.argv[1:])
