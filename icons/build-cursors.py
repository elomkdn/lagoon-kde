"""Teal, les curseurs de Lagoon : Catppuccin Mocha Teal (vendor/catppuccin-cursors, à partir de Volantes),
retouchés pour se voir partout, même sur le teal du thème :

  - un contour sombre plus épais (les silhouettes seulement, pas les détails dessinés dessus) ;
  - un dégradé écume → teal → sapphire à la place du teal plein ;
  - une flèche aux coins arrondis, dans l'esprit de Bibata Modern (un tracé original).

Écrit cursors_scalable/ (les SVG que Plasma met à l'échelle) et cursors/ (les Xcursor, rendus
depuis ces mêmes SVG, pour X11 et XWayland), avec les alias de Catppuccin en liens symboliques.

    python3 build-cursors.py <archive Catppuccin> <dossier du thème>

Nécessite rsvg-convert (librsvg) ; aucun module Python à installer.
"""
import json, os, re, stat, struct, subprocess, sys, zipfile, zlib
from concurrent.futures import ProcessPoolExecutor

ROOT = "catppuccin-mocha-teal-cursors/"
TEAL, BASE, BLACK = "#94e2d5", "#1e1e2e", "#000"
EXTRA = 1.4                 # épaisseur ajoutée aux silhouettes (toile de 32 px pour la taille 24)
SIZES = range(12, 73, 6)    # les tailles Xcursor de Catppuccin ; la toile fait 4/3 de la taille
MORE_ALIASES = {"dnd-link": "alias"}

GRADIENT = ('<linearGradient id="lagoon-g" x1="0" y1="0" x2="0.35" y2="1">'
            '<stop offset="0" stop-color="#b5f0e6"/><stop offset="0.45" stop-color="#94e2d5"/>'
            '<stop offset="1" stop-color="#74c7ec"/></linearGradient>'
            '<filter id="lagoon-s" x="-.2" y="-.2" width="1.4" height="1.4"><feGaussianBlur stdDeviation=".57"/></filter>')
G = "url(#lagoon-g)"

# --- La flèche arrondie ------------------------------------------------------------------------
# Un tracé intérieur, élargi par un trait à jointures rondes : les coins s'arrondissent d'eux-mêmes.
# La pointe arrive en (2, 2), le point chaud de Catppuccin ; même encombrement que sa flèche.
CORE = ("M3.3,3.3 L3.3,20 C4.2,17.6 6.1,15.6 8,14.6 C9.3,13.9 10.8,13.5 12.2,13.5 "
        "C13.1,13.5 13.9,13.8 14.6,14.1 Z")
ROUND, EDGE = 1.5, 1 + EXTRA / 2   # rayon des coins ; contour visible autour du teal


def arrow(transform=""):
    t = f' transform="{transform}"' if transform else ""
    w = 2 * (ROUND + EDGE)
    return (f'<g{t}>'
            f'<path class="lagoon" d="{CORE}" fill="{BLACK}" stroke="{BLACK}" stroke-width="{w}" stroke-linejoin="round" '
            f'opacity=".2" filter="url(#lagoon-s)" transform="translate(.5 .5)"/>'
            f'<path class="lagoon" d="{CORE}" fill="{BASE}" stroke="{BASE}" stroke-width="{w}" stroke-linejoin="round"/>'
            f'<path class="lagoon" d="{CORE}" fill="{G}" stroke="{G}" stroke-width="{2 * ROUND}" stroke-linejoin="round"/></g>')


# les trois couches (ombre, silhouette, teal) de la flèche de Catppuccin, et de son miroir right_ptr
OLD_ARROW = [
    "M2.462 1.501a1 1 0 0 0-.948.998L1.5 22.498c-.001 1.136 1.59 1.394 1.948.316.91-2.735 3.035-5.176 5.113-6.284 1.276-.65 2.635-1.02 3.932-1.03a7.4 7.4 0 0 1 3.525.881c1.034.556 2.013-.818 1.152-1.615L3.194 1.767a1 1 0 0 0-.732-.266",
    "M1.962 1.001A1 1 0 0 0 1.014 2L1 21.998c-.001 1.136 1.59 1.394 1.948.316.91-2.735 3.035-5.176 5.113-6.284 1.276-.65 2.635-1.02 3.932-1.03a7.4 7.4 0 0 1 3.525.881c1.034.556 2.013-.818 1.152-1.615L2.694 1.267a1 1 0 0 0-.732-.266",
    "M2.014 2 2 22c1-3 3.247-5.604 5.603-6.857C9.023 14.419 10.54 14.01 12 14a8.4 8.4 0 0 1 4 1z",
]
OLD_MIRROR = [
    "M29.538 1.501a1 1 0 0 1 .948.998l.014 19.999c.001 1.136-1.59 1.394-1.948.316-.91-2.735-3.035-5.176-5.113-6.284-1.276-.65-2.635-1.02-3.932-1.03a7.4 7.4 0 0 0-3.525.881c-1.034.556-2.013-.818-1.152-1.615L28.806 1.767a1 1 0 0 1 .732-.266",
    "M29.038 1.001a1 1 0 0 1 .948.998L30 21.998c.001 1.136-1.59 1.394-1.948.316-.91-2.735-3.035-5.176-5.113-6.284-1.276-.65-2.635-1.02-3.932-1.03a7.4 7.4 0 0 0-3.525.881c-1.034.556-2.013-.818-1.152-1.615L28.306 1.267a1 1 0 0 1 .732-.266",
    "M28.986 2 29 22c-1-3-3.247-5.604-5.603-6.857C21.977 14.419 20.46 14.01 19 14a8.4 8.4 0 0 0-4 1z",
]


def element(d):
    return re.compile(r'<path\b[^>]*?\bd="%s"[^>]*?/>' % re.escape(d), re.S)


def swap_arrow(svg):
    for old, new in ((OLD_ARROW, arrow()), (OLD_MIRROR, arrow("matrix(-1 0 0 1 31 0)"))):
        found = [element(d).search(svg) for d in old]
        if all(found):
            svg = element(old[0]).sub(new, svg, count=1)
            svg = element(old[1]).sub("", svg, count=1)
            svg = element(old[2]).sub("", svg, count=1)
        elif any(found):
            raise SystemExit("flèche de Catppuccin incomplète : l'archive a changé ?")
    return svg


# --- Dégradé et contour ------------------------------------------------------------------------
SHAPE = re.compile(r'<(?:path|circle|ellipse|rect)\b[^>]*?/>', re.S)


def fill_of(el):
    if 'display="none"' in el:
        return None
    m = re.search(r'fill:\s*([^;"]+)', el) or re.search(r'\bfill="([^"]+)"', el)
    return m.group(1).strip().lower() if m else None


def thicken(el):
    """Une silhouette : un trait de sa couleur, à jointures rondes, l'élargit de EXTRA."""
    color = fill_of(el)
    if 'style="' in el:
        def restyle(m):
            st = re.sub(r"(^|;)\s*stroke(-width|-linejoin|-linecap)?\s*:[^;]*", "", m.group(1))
            return f'style="{st};stroke:{color};stroke-width:{EXTRA};stroke-linejoin:round;stroke-linecap:round"'
        return re.sub(r'style="([^"]*)"', restyle, el, count=1)
    el = re.sub(r'\s(stroke|stroke-width|stroke-linejoin|stroke-linecap)="[^"]*"', "", el)
    return el.replace("<path", f'<path stroke="{color}" stroke-width="{EXTRA}" stroke-linejoin="round"', 1)


def retouch(svg):
    svg = svg.replace(f"fill:{TEAL}", f"fill:{G}").replace(f'fill="{TEAL}"', f'fill="{G}"')
    svg = svg.replace("<defs>", "<defs>" + GRADIENT, 1) if "<defs>" in svg else \
        re.sub(r"(<svg\b[^>]*>)", r"\1<defs>" + GRADIENT + "</defs>", svg, count=1)
    svg = swap_arrow(svg)
    # une silhouette, c'est l'ombre ou le fond sombre juste sous une forme teal : les deux
    # éléments qui la précèdent. Les détails sombres dessinés par-dessus le teal restent fins.
    els = list(SHAPE.finditer(svg))
    marks = set()
    for i, m in enumerate(els):
        if fill_of(m.group()) == G:
            for j in (i - 1, i - 2):
                if j >= 0 and fill_of(els[j].group()) in (BASE, BLACK) and 'class="lagoon"' not in els[j].group():
                    marks.add(j)
    for j in sorted(marks, reverse=True):
        m = els[j]
        svg = svg[:m.start()] + thicken(m.group()) + svg[m.end():]
    return svg


# --- Xcursor -----------------------------------------------------------------------------------
def decode_png(data):
    """RGBA 8 bits non entrelacé (ce qu'écrit rsvg-convert) → octets RGBA."""
    pos, idat = 8, []
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        pos += 12 + n
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if (depth, ctype, interlace) != (8, 6, 0):
                raise ValueError("PNG inattendu de rsvg-convert")
        elif kind == b"IDAT":
            idat.append(body)
    raw, stride = zlib.decompress(b"".join(idat)), w * 4
    out, prev = bytearray(), bytearray(stride)
    for y in range(h):
        f, row = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        if f:
            for i in range(stride):
                a = row[i - 4] if i >= 4 else 0
                b = prev[i]
                if f == 1:
                    row[i] = (row[i] + a) & 255
                elif f == 2:
                    row[i] = (row[i] + b) & 255
                elif f == 3:
                    row[i] = (row[i] + (a + b) // 2) & 255
                else:
                    c = prev[i - 4] if i >= 4 else 0
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    row[i] = (row[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out += row
        prev = row
    return out


def render(job):
    """Un SVG à une taille de toile → pixels ARGB prémultipliés, petit-boutistes (format Xcursor)."""
    path, side = job
    png = subprocess.run(["rsvg-convert", "-w", str(side), "-h", str(side), path],
                         check=True, capture_output=True).stdout
    rgba = decode_png(png)
    argb = bytearray(len(rgba))
    for i in range(0, len(rgba), 4):
        r, g, b, a = rgba[i:i + 4]
        argb[i:i + 4] = ((b * a + 127) // 255, (g * a + 127) // 255, (r * a + 127) // 255, a)
    return bytes(argb)


def write_xcursor(path, images):
    """images : (taille nominale, côté de la toile, point chaud x, y, délai, pixels)."""
    toc, chunks, start = b"", b"", 16 + 12 * len(images)
    for nominal, side, hx, hy, delay, pixels in images:
        toc += struct.pack("<III", 0xFFFD0002, nominal, start + len(chunks))
        chunks += struct.pack("<9I", 36, 0xFFFD0002, nominal, 1, side, side, hx, hy, delay) + pixels
    with open(path, "wb") as f:
        f.write(b"Xcur" + struct.pack("<III", 16, 0x10000, len(images)) + toc + chunks)


# --- Thème -------------------------------------------------------------------------------------
def main(archive, theme):
    z = zipfile.ZipFile(archive)
    scalable, xcursors = os.path.join(theme, "cursors_scalable"), os.path.join(theme, "cursors")
    os.makedirs(scalable, exist_ok=True)
    os.makedirs(xcursors, exist_ok=True)
    aliases, cursors = {}, {}
    for info in z.infolist():
        name = info.filename.removeprefix(ROOT)
        if name in ("AUTHORS", "LICENSE"):
            with open(os.path.join(theme, name), "wb") as f:
                f.write(z.read(info))
        if not name.startswith("cursors_scalable/") or info.is_dir():
            continue
        parts = name.split("/")[1:]
        if stat.S_ISLNK(info.external_attr >> 16):
            aliases[parts[0]] = z.read(info).decode()
        elif len(parts) == 2:
            cursors.setdefault(parts[0], {})[parts[1]] = z.read(info).decode()
    aliases.update(MORE_ALIASES)

    jobs, plan = [], []
    for cursor, files in sorted(cursors.items()):
        folder = os.path.join(scalable, cursor)
        os.makedirs(folder, exist_ok=True)
        meta = json.loads(files["metadata.json"])
        with open(os.path.join(folder, "metadata.json"), "w") as f:
            f.write(files["metadata.json"])
        frames = []
        for entry in meta:
            path = os.path.join(folder, entry["filename"])
            with open(path, "w") as f:
                f.write(retouch(files[entry["filename"]]))
            frames.append((path, entry))
        plan.append((cursor, frames))
        jobs += [(path, size * 4 // 3) for path, _ in frames for size in SIZES]

    with ProcessPoolExecutor() as pool:
        pixels = dict(zip(jobs, pool.map(render, jobs, chunksize=8)))
    for cursor, frames in plan:
        images = []
        for path, e in frames:  # image par image, toutes les tailles, comme Catppuccin
            for size in SIZES:
                side = size * 4 // 3
                images.append((size, side, int(e["hotspot_x"] * side / 32), int(e["hotspot_y"] * side / 32),
                               e.get("delay", 50), pixels[(path, side)]))
        write_xcursor(os.path.join(xcursors, cursor), images)

    for alias, target in aliases.items():
        assert target in cursors or target in aliases, (alias, target)
        for folder in (scalable, xcursors):
            link = os.path.join(folder, alias)
            if os.path.lexists(link):
                os.remove(link)
            os.symlink(target, link)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
