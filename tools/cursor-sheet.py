#!/usr/bin/env python3
"""La planche des curseurs Teal pour le README : les plus courants côte à côte, avec leur nom,
sur le fond Mocha de la planche des icônes (screenshots/teal-icons.png). Une rangée de plus les
pose sur l'accent teal et sur un fond clair : on les voit partout.

usage : tools/cursor-sheet.py <dossier cursors_scalable des curseurs construits> <sortie.png>
ex.   : tools/cursor-sheet.py dist/Lagoon/share/icons/Teal-cursors/cursors_scalable screenshots/teal-cursors.png
Nécessite rsvg-convert et Pillow.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BASE, SURFACE0, SUBTEXT, TEAL, LATTE = "#1e1e2e", "#313244", "#a6adc8", "#94e2d5", "#eff1f5"
FONT = "/usr/share/fonts/inter/Inter.ttc"
SCALE = 3          # leur taille nominale (24 px) agrandie trois fois
CELL, ROW = 147, 150

CURSORS = [("default", "Default"), ("pointer", "Link"), ("text", "Text"), ("wait", "Busy"),
           ("progress", "Working"), ("help", "Help"), ("crosshair", "Crosshair"), ("openhand", "Grab"),
           ("closedhand", "Grabbing"), ("not-allowed", "Not allowed"), ("all-scroll", "Move"),
           ("ew-resize", "Resize"), ("nwse-resize", "Diagonal"), ("copy", "Copy"), ("zoom-in", "Zoom"),
           ("color-picker", "Color picker")]
# la dernière rangée : le curseur par défaut, la main et le texte sur l'accent et sur du clair
ON = [(TEAL, "default"), (TEAL, "pointer"), (TEAL, "text"), (TEAL, "openhand"),
      (LATTE, "default"), (LATTE, "pointer"), (LATTE, "text"), (LATTE, "openhand")]


def render(folder, name, tmp):
    """Le curseur (la première image d'un animé) à SCALE fois sa taille."""
    d = folder / name
    meta = json.loads((d / "metadata.json").read_text())[0]
    size = meta["nominal_size"] * SCALE
    out = Path(tmp) / f"{name}.png"
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), str(d / meta["filename"]), "-o", str(out)],
                   check=True)
    # rognée à ce qu'elle montre, pour la centrer (le point chaud la pousse dans un coin)
    image = Image.open(out).convert("RGBA")
    image = image.crop(image.getbbox())
    return image, image.size


def main():
    folder, output = Path(sys.argv[1]), Path(sys.argv[2])
    columns = 8
    rows = -(-len(CURSORS) // columns)
    width, height = columns * CELL, (rows + 1) * ROW + 10
    sheet = Image.new("RGBA", (width, height), BASE)
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(FONT, 15, index=0)
    with tempfile.TemporaryDirectory() as tmp:
        for i, (name, label) in enumerate(CURSORS):
            x, y = (i % columns) * CELL, (i // columns) * ROW
            image, (w, h) = render(folder, name, tmp)
            sheet.alpha_composite(image, (x + (CELL - w) // 2, y + 18 + (72 - h) // 2))
            tw = draw.textlength(label, font=font)
            draw.text((x + (CELL - tw) / 2, y + 100), label, font=font, fill=SUBTEXT)
        # sur l'accent et sur du clair : une pastille par fond, comme une sélection
        y = rows * ROW + 16
        for i, (background, name) in enumerate(ON):
            x = i * CELL
            draw.rounded_rectangle((x + 14, y, x + CELL - 14, y + ROW - 32), radius=13, fill=background)
            image, (w, h) = render(folder, name, tmp)
            sheet.alpha_composite(image, (x + (CELL - w) // 2, y + (ROW - 32 - h) // 2))
    sheet.convert("RGB").save(output, optimize=True)


if __name__ == "__main__":
    main()
