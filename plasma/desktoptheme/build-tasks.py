#!/usr/bin/env python3
"""Le cadre des tâches du gestionnaire de tâches (widgets/tasks.svg).

Plasma dessine sous chaque tâche un cadre (FrameSvg) de neuf pièces, choisi selon l'état de la
fenêtre (normal, focus, hover, attention, minimized ; progress pour la barre de progression par
dessus) et le bord du panneau (sans préfixe en bas, north-, west-, east-). Toutes les pièces
sont transparentes, sauf le bord côté écran, qui porte le trait : un trait arrondi, long pour
une fenêtre à l'écran, court pour une fenêtre réduite ; la couleur dit si elle a le focus.

Plasma étire ce bord sur la largeur de la tâche (hint-stretch-borders) : il est dessiné à
EDGE, la largeur d'une tâche du dock de Lagoon (72 px de haut), pour que le trait n'y soit
presque pas étiré et que ses bouts restent ronds.

Les marges des icônes viennent des pièces elles-mêmes (côtés, haut et bas) et des pièces
hint-*-margin : leurs tailles sont celles de Breeze, dont ce cadre est tiré.

usage : plasma/desktoptheme/build-tasks.py sortie.svg
"""
import sys

# --- Le trait ---
THICK = 4        # épaisseur
EDGE = 72        # longueur du bord qui le porte, celle d'une tâche du dock
LONG = 28        # fenêtre à l'écran
SHORT = 14       # fenêtre réduite : plus court plutôt que plus pâle ; coupé par l'encoche des
                 # groupes, chaque moitié garde 5 px (Plasma pose l'encoche au pixel près, le
                 # trait étiré tombe entre deux : un pixel de plus d'un côté se voit sur 3 px)

# état : (couleur, opacité, longueur du trait) ; le survol prend la place des autres états
STATES = {
    "normal": ("#fff", .6, LONG),
    "focus": ("#94e2d5", 1, LONG),
    "hover": ("#94e2d5", .5, LONG),
    "attention": ("#ffb54d", 1, LONG),
    "minimized": ("#fff", .6, SHORT),
}

# --- La barre de progression : par-dessus la tâche, coupée à la part faite ---
PROGRESS = ("#27ad60", .61176)

# --- Plusieurs fenêtres dans une tâche : une encoche coupe le trait en deux. Plasma la pose par
# dessus, centrée sur l'icône, contre le bord, sans dire l'état de la fenêtre : elle prend la
# couleur du fond, pas celle du trait, qui garde ainsi celle de l'état (un point à côté du trait
# restait d'une seule couleur, gris à côté du sarcelle) ---
NOTCH = ("#1e1e2e", THICK)

# Tailles des pièces (largeur, hauteur) : en bas et en haut, à gauche et à droite
HORIZONTAL = {"corner": (4, 3), "hedge": (26, 3), "vedge": (4, 13), "center": (26, 13)}
VERTICAL = {"corner": (3, 4), "hedge": (28, 4), "vedge": (3, 11), "center": (28, 11)}
# bord : (préfixe, pièce côté écran, tailles)
EDGES = {
    "bottom": ("", "bottom", HORIZONTAL),
    "top": ("north-", "top", HORIZONTAL),
    "left": ("west-", "left", VERTICAL),
    "right": ("east-", "right", VERTICAL),
}
PIECES = ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright")
GAP = 2


def n(x):
    return f"{x:g}"


def size(piece, sizes):
    if piece == "center":
        return sizes["center"]
    if piece in ("top", "bottom"):
        return sizes["hedge"]
    if piece in ("left", "right"):
        return sizes["vedge"]
    return sizes["corner"]


def bar(x, y, w, h, length, color, opacity, round_ends=True):
    """Un trait de `length` centré dans la pièce (x, y, w, h), sur toute son épaisseur."""
    horizontal = w > h
    if horizontal:
        bx, by, bw, bh = x + (w - length) / 2, y, length, h
    else:
        bx, by, bw, bh = x, y + (h - length) / 2, w, length
    rx = f' rx="{n(min(bw, bh) / 2)}"' if round_ends else ""
    op = "" if opacity == 1 else f' opacity="{n(opacity)}"'
    return f'<rect x="{n(bx)}" y="{n(by)}" width="{n(bw)}" height="{n(bh)}"{rx} fill="{color}"{op}/>'


def piece(pid, x, y, w, h, content=""):
    box = f'<rect x="{n(x)}" y="{n(y)}" width="{n(w)}" height="{n(h)}" fill="none"/>'
    if not content:
        return f' <g id="{pid}">{box}</g>', w, h
    return f' <g id="{pid}">\n  {box}\n  {content}\n </g>', w, h


def frame(prefix, outer, sizes, y, state):
    """Les neuf pièces d'un cadre, en une ligne à partir de (0, y) ; renvoie (svg, largeur, hauteur)."""
    out, x, height = [], 0, 0
    for p in PIECES:
        w, h = size(p, sizes)
        content = ""
        if p == outer and state in STATES:
            color, opacity, length = STATES[state]
            w, h = (EDGE, THICK) if outer in ("top", "bottom") else (THICK, EDGE)
            content = bar(x, y, w, h, length, color, opacity)
        elif p == outer and state == "progress":
            color, opacity = PROGRESS
            # en bas, un trait court, comme celui de Breeze ; ailleurs, tout le bord
            length = 10 if outer == "bottom" else max(w, h)
            content = bar(x, y, w, h, length, color, opacity, round_ends=False)
        svg, w, h = piece(f"{prefix}{state}-{p}", x, y, w, h, content)
        out.append(svg)
        x += w + GAP
        height = max(height, h)
    return out, x, height


def main():
    out, y, width = [], 0, 0
    for state in (*STATES, "progress"):
        for edge, (prefix, outer, sizes) in EDGES.items():
            lines, w, h = frame(prefix, outer, sizes, y, state)
            out += lines
            y += h + GAP
            width = max(width, w)

    # Marges du contenu (en haut et en bas) et bords étirés, comme Breeze : pour les cadres sans
    # préfixe de bord seulement
    hints, x = [], 0
    for state in (*STATES, "progress"):
        hints.append(f' <rect id="{state}-hint-top-margin" x="{x}" y="{y}" width="2" height="1" fill="none"/>')
        hints.append(f' <rect id="{state}-hint-bottom-margin" x="{x}" y="{y + 4}" width="2" height="1" fill="none"/>')
        hints.append(f' <rect id="{state}-hint-stretch-borders" x="{x + 3}" y="{y}" width="1" height="1" fill="none"/>')
        x += 6
    hints.append(f' <rect id="hint-stretch-borders" x="{x}" y="{y}" width="1" height="1" fill="none"/>')
    y += 5 + GAP

    # L'encoche des groupes : un carré de l'épaisseur du trait
    color, t = NOTCH
    groups = []
    for i, edge in enumerate(("bottom", "top", "left", "right")):
        groups.append(f' <rect id="group-expander-{edge}" x="{i * (t + GAP)}" y="{y}" width="{t}" height="{t}"'
                      f' fill="{color}"/>')
    y += t

    svg = (f'<svg width="{width}" height="{y}" viewBox="0 0 {width} {y}" xmlns="http://www.w3.org/2000/svg">\n'
           + "\n".join(out + hints + groups) + "\n</svg>\n")
    with open(sys.argv[1], "w") as f:
        f.write(svg)


main()
