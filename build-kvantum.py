#!/usr/bin/env python3
"""Construit le thème Kvantum « Lagoon » à partir de KvLibadwaita Dark (GabePoel) :
le style des applis GNOME (libadwaita) pour les applis Qt, aux couleurs Catppuccin Mocha avec
l'accent teal et aux rayons du thème GTK (9 px).

- les gris neutres de libadwaita passent sur les gris Mocha, rôle par rôle, avec la
  convention du jeu de couleurs Catppuccin et du thème GTK : le cadre (fond des fenêtres,
  barres de menus et d'outils) en mantle, le contenu (vues) en base, les champs un cran
  au-dessus, les boutons en surface0 ; son bleu passe sur le teal ; les coches et les points
  posés sur l'accent deviennent sombres (crust). Les applis Qt Widgets ressemblent ainsi aux
  applis Kirigami, qui suivent le jeu de couleurs ;
- menus et infobulles : la base Mocha à POPUP_ALPHA, floutée, comme les popups de Plasma ; les
  fenêtres restent opaques (leur fond l'est), mais Kvantum ne floute les popups dès leur
  ouverture qu'avec la translucidité des fenêtres (translucent_windows, blurring) : sans elle,
  popup_blurring seul n'applique pas le flou, sous Wayland, et les menus laissent voir net ce
  qu'il y a derrière ;
- sélections des listes : l'accent teal et un texte sombre, avec ou sans focus, comme dans
  GTK, Kirigami et le jeu de couleurs Catppuccin (voir SELECTION) ;
- curseurs et barres de progression : les épaisseurs de libadwaita (4 et 8 px), comme GTK ;
- poignée des curseurs : un disque plein en text, comme celles de GTK et de Plasma (l'anneau
  teal de KvLibadwaita était la seule de son espèce) ;
- rayons : les coins de KvLibadwaita sont des quarts de disque pleins, à l'échelle de la
  taille du cadre (frame.*) : le cadre donne le rayon. L'anneau de focus des champs, lui,
  grossirait avec : il est redessiné pour garder 2 px.

usage : build-kvantum.py <dossier KvLibadwaita> <dossier de sortie> <nom>
"""
import copy
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# Catppuccin Mocha
CRUST, MANTLE, BASE = "#11111b", "#181825", "#1e1e2e"
SURFACE0, SURFACE1, SURFACE2 = "#313244", "#45475a", "#585b70"
OVERLAY0, OVERLAY1, OVERLAY2 = "#6c7086", "#7f849c", "#9399b2"
SUBTEXT0, SUBTEXT1, TEXT = "#a6adc8", "#bac2de", "#cdd6f4"
TEAL, MAUVE, RED = "#94e2d5", "#cba6f7", "#f38ba8"


def mix(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


POPUP = BASE                              # comme les popups de Plasma : la base Mocha
POPUP_ALPHA = 0.75                        # et la même opacité (build-translucent.py)
FIELD = mix(BASE, SURFACE0, 0.75)         # champs : un cran au-dessus de la fenêtre
HOVER = mix(BASE, SURFACE0, 0.8)          # ligne survolée
TEAL_HOVER = mix(TEAL, TEXT, 0.25)        # accent survolé, un peu plus clair
FOCUS_RING = mix(BASE, TEAL, 0.5)         # anneau de focus, comme l'accent à 50 % de GTK
# Sélections des listes, texte sombre (crust) comme dans GTK et Kirigami :
# - avec ou sans focus : l'accent lui-même (12,6:1 avec le texte). Les dossiers Teal, de la même
#   couleur, s'en détachent par leur ombre (teal-icons, add_folder_shadow). Le panneau
#   Emplacements de KIO (Dolphin, boîtes de dialogue de fichiers des applis KDE) écrit en texte
#   clair tant qu'il n'a pas le focus, quel que soit le style : son libellé sélectionné se lit
#   mal, le prix d'une seule teinte partout ;
# - fenêtre inactive : un teal adouci (contraste 5,7:1).
SELECTION = TEAL
SELECTION_INACTIVE = mix(TEAL, BASE, 0.4)
INACTIVE_ACCENT = mix(OVERLAY1, TEAL, 0.25)  # l'accent éteint des fenêtres inactives
FOCUS_FRAMES = ("button", "combo", "tab")   # les contrôles entourés d'un anneau de focus
DEFAULT_TINT = 0.25                         # bouton par défaut : voile teal

# Couleurs de KvLibadwaita Dark -> Mocha, par rôle (voir dev/color-assignment.json de KvLibadwaita)
SVG_COLORS = {
    "#1d1d20": MANTLE, "#222226": MANTLE,                  # fond des fenêtres, barres inactives
    "#212121": BASE, "#2c2c2c": BASE,                      # cadre d'onglets, poignée du curseur
    "#2e2e32": FIELD,                                      # champs, listes déroulantes
    "#3d3d3d": HOVER,                                      # ligne survolée
    "#414141": SURFACE0, "#444444": mix(SURFACE0, SURFACE1, 0.15),  # boutons
    "#4f4f4f": mix(SURFACE0, SURFACE1, 0.5), "#4b4b4b": mix(SURFACE0, SURFACE1, 0.5),  # survol
    "#616161": mix(SURFACE1, SURFACE2, 0.3), "#797979": SURFACE2,   # appuyé
    "#6e6e6e": mix(SURFACE1, SURFACE2, 0.8),               # bouton enfoncé (toggled)
    "#404040": SURFACE1, "#525252": SURFACE1,              # bord des cases
    "#5a5a5a": OVERLAY0, "#646464": OVERLAY0, "#666666": OVERLAY0, "#5a616e": OVERLAY0,
    "#707070": OVERLAY1, "#989898": OVERLAY2,              # barres de défilement
    "#b6b6b6": SUBTEXT0, "#c1c1c1": SUBTEXT0, "#acb1bc": SUBTEXT0,
    "#dfdfdf": TEXT, "#ffffff": TEXT,                      # flèches, reflets
    "#f2ffff": CRUST,                                      # coches posées sur l'accent
    "#3584e4": TEAL, "#4285f4": TEAL, "#3daee9": TEAL, "#93cee9": TEAL,
    "#4990e7": TEAL_HOVER,
    "#587392": FOCUS_RING,
    "#f04a50": RED,
}
# Même couleur d'origine, rôle différent selon l'élément
SCOPED = {
    r"^menu-(normal|shadow)": {"#2e2e32": POPUP},
    r"^menubar-normal": {"#2e2e32": MANTLE},               # barres de menus et d'outils
    r"^dock": {"#2c2c2c": MANTLE},
    r"^(menu-)?(checkbox|radio)": {"#1d1d20": BASE},       # intérieur des cases
    r"^tooltip-normal": {"#000006": POPUP},
    r"^itemview-toggled": {"#4b4b4b": SELECTION},
    r"^itemview-pressed": {"#616161": SELECTION},
    r"^slidercursor": {"#3584e4": TEXT, "#2c2c2c": TEXT},  # poignée pleine (anneau et centre)
    r"^slidercursor(-tickless)?-disabled": {TEXT: OVERLAY0},  # désactivée, elle s'efface
    r"^(checkbox|radio)-focused": {"#4b4b4b": SURFACE2},   # survolé : bord plus clair qu'au repos
}
# Fonds des menus et des infobulles, à POPUP_ALPHA (KvLibadwaita : infobulles noires à 80 %)
POPUPS = r"^(menu-(normal|shadow)|tooltip-normal)"  # l'ombre des menus dessine le bord de leur fond

GENERAL_COLORS = {
    "window.color": MANTLE, "base.color": BASE, "alt.base.color": MANTLE,  # comme le jeu de couleurs
    "button.color": SURFACE0, "light.color": SURFACE1, "mid.light.color": mix(SURFACE0, SURFACE1, 0.5),
    "dark.color": MANTLE, "mid.color": SURFACE0,
    "highlight.color": TEAL, "inactive.highlight.color": SELECTION_INACTIVE,
    "text.color": TEXT, "window.text.color": TEXT, "button.text.color": TEXT,
    "disabled.text.color": OVERLAY1, "tooltip.base.color": POPUP, "tooltip.text.color": TEXT,
    "highlight.text.color": CRUST, "inactive.highlight.text.color": CRUST,
    "link.color": TEAL, "link.visited.color": MAUVE, "progress.indicator.text.color": TEXT,
}

RADIUS = 9
OPAQUE_APPS = ("kaffeine,kmplayer,subtitlecomposer,kdenlive,vlc,smplayer,smplayer2,avidemux,"
               "avidemux2_qt4,avidemux3_qt4,avidemux3_qt5,kamoso,QtCreator,VirtualBox,VirtualBoxVM,"
               "trojita,dragon,digikam,lyx")

# Rayons. Kvantum dessine les coins à la taille du cadre, qui compte aussi dans la taille des
# widgets. Avec frame.expansion et des pièces « expand-<élément> » dans le SVG, il les dessine
# à la moitié de l'expansion, sans changer les marges : le rayon voulu, à la densité de
# KvLibadwaita. Les pièces expand- sont des copies de celles de KvLibadwaita (coins en quarts
# de disque pleins, à l'échelle). Onglets : coin de 8 dont 2 de marge -> 12 pour un arrondi
# de 9. Les menus n'ont pas d'expansion : leur cadre de 9 donne leur rayon (le thème GTK
# arrondit les siens de même). Les boutons des barres d'outils restent en pilule, comme les
# boutons plats et ceux des fenêtres dans le thème GTK.
EXPAND = {  # élément du SVG : (sections du kvconfig, taille des coins)
    "button": (("PanelButtonCommand", "PanelButtonTool"), RADIUS),
    "lineedit": (("LineEdit",), RADIUS),
    "combo": (("ComboBox",), RADIUS),
    "itemview": (("ItemView",), RADIUS),
    "menuitem": (("MenuItem",), RADIUS),
    "tooltip": (("ToolTip",), RADIUS),
    "tab": (("Tab",), RADIUS + 3),
}
SETTINGS = {
    "%General": {"author": "Elom, based on KvLibadwaita by GabePoel",
                 "comment": "Lagoon: the libadwaita look in Catppuccin Mocha with a teal accent",
                 # menus et infobulles translucides et floutés (voir plus haut) ; les applis qui
                 # dessinent de la vidéo ou de l'OpenGL gardent des fenêtres opaques (la liste de
                 # KvMojave, le thème translucide de Kvantum)
                 "translucent_windows": "true", "blurring": "true", "popup_blurring": "true",
                 "reduce_window_opacity": "0", "reduce_menu_opacity": "0",
                 "menu_blur_radius": str(RADIUS), "tooltip_blur_radius": str(RADIUS),
                 "opaque": OPAQUE_APPS,
                 # chaque bouton d'outils garde ses quatre coins, même collé à un voisin
                 "group_toolbar_buttons": "false", "toolbar_item_spacing": "2",
                 "combo_focus_rect": "true",
                 # les épaisseurs de libadwaita, celles du thème GTK
                 "slider_width": "4", "progressbar_thickness": "8"},
    "Menu": {f"frame.{side}": str(RADIUS) for side in ("top", "bottom", "left", "right")},
    # vue de Dolphin transparente : elle prendrait le fond des fenêtres (mantle) au lieu de base
    "Hacks": {"transparent_dolphin_view": "false"},
    "ItemView": {"text.press.color": CRUST, "text.press.inactive.color": CRUST,
                 "text.toggle.color": CRUST, "text.toggle.inactive.color": CRUST},
    # pas de rectangle pointillé de focus en plus : l'élément sélectionné se voit déjà à son fond
    "Focus": {"frame": "false"},
    # à la place, un anneau arrondi autour du contrôle qui a le focus, comme celui des champs ;
    # Kvantum ne distingue pas le clavier de la souris : il reste aussi après un clic
    "PanelButtonCommand": {"focusFrame": "true"},
    "ComboBox": {"focusFrame": "true"},
    "Tab": {"focusFrame": "true"},
    # bouts ronds, comme GTK : des cadres de la moitié de l'épaisseur (ceux hérités des boutons,
    # plus hauts que la barre, seraient abandonnés par Kvantum, qui la dessinerait carrée)
    "Slider": {f"frame.{side}": "2" for side in ("top", "bottom", "left", "right")},
    "Progressbar": {f"frame.{side}": "4" for side in ("top", "bottom", "left", "right")},
    "ProgressbarContents": {f"frame.{side}": "4" for side in ("top", "bottom", "left", "right")},
}
for sections, corner in EXPAND.values():
    for section in sections:
        SETTINGS.setdefault(section, {})["frame.expansion"] = str(2 * corner)

SVG_NS = "http://www.w3.org/2000/svg"
for prefix, uri in {"": SVG_NS, "xlink": "http://www.w3.org/1999/xlink",
                    "inkscape": "http://www.inkscape.org/namespaces/inkscape",
                    "sodipodi": "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd",
                    "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
                    "cc": "http://creativecommons.org/ns#", "dc": "http://purl.org/dc/elements/1.1/"}.items():
    ET.register_namespace(prefix, uri)

HEX = re.compile(r"#[0-9a-fA-F]{6}\b")
PARTS = r"(-(top|bottom|left|right|topleft|topright|bottomleft|bottomright))?"


def set_style(e, **props):
    """Remplace des propriétés de l'attribut style (et retire les attributs équivalents)."""
    style = dict(kv.split(":", 1) for kv in (e.get("style") or "").split(";") if ":" in kv)
    style = {k.strip(): v.strip() for k, v in style.items()}
    for k, v in props.items():
        k = k.replace("_", "-")
        style[k] = v
        e.attrib.pop(k, None)
    e.set("style", ";".join(f"{k}:{v}" for k, v in style.items()))


def recolor_attrs(e, mapping):
    for x in e.iter():
        for attr in ("style", "fill", "stroke"):
            if x.get(attr):
                x.set(attr, HEX.sub(lambda m: mapping.get(m.group(0).lower(), m.group(0)), x.get(attr)))


def build_svg(text):
    root = ET.fromstring(text)
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    parents = {c: p for p in root.iter() for c in p}

    # bouton d'outils enfoncé : le bord gauche, repris par le droit, est vide chez KvLibadwaita
    # et laisse une encoche sombre au bout d'un groupe, comme sur le bouton retour de Dolphin
    set_style(ids["tbutton-pressed-left"][0], opacity="1", fill_opacity="1")

    # piste du curseur, à droite de la poignée : du noir à 25 % chez KvLibadwaita, invisible ici
    for eid, e in ids.items():
        if re.match(rf"^slider-normal{PARTS}$", eid):
            for x in e.iter():
                if x.tag.endswith("rect"):
                    x.attrib.pop("opacity", None)
                    set_style(x, fill=SURFACE1, opacity="1")

    # bouts ronds des curseurs et des barres de progression : leurs coins, des carrés pleins chez
    # KvLibadwaita (invisibles à 2 px d'épaisseur), deviennent des quarts de disque
    for eid, e in ids.items():
        m = re.match(r"^(?:slider-(?:normal|toggled)|progress-normal|progress-pattern-(?:normal|disabled))"
                     r"-(top|bottom)(left|right)$", eid)
        if m and e.tag.endswith("rect"):
            x, y, w, h = (float(e.get(k)) for k in ("x", "y", "width", "height"))
            cx, far_x = (x + w, x) if m.group(2) == "left" else (x, x + w)   # centre du disque, bord opposé
            cy, far_y = (y + h, y) if m.group(1) == "top" else (y, y + h)
            sweep = 0 if (m.group(1) == "top") == (m.group(2) == "left") else 1
            e.tag = f"{{{SVG_NS}}}path"
            for k in ("x", "y", "width", "height"):
                del e.attrib[k]
            e.set("d", f"M {cx:g},{far_y:g} A {w:g},{h:g} 0 0 {sweep} {far_x:g},{cy:g} L {cx:g},{cy:g} Z")

    # 1. rôles propres à certains éléments, puis fonds des menus et des infobulles
    for eid, e in ids.items():
        for pattern, mapping in SCOPED.items():
            if re.match(pattern, eid):
                recolor_attrs(e, mapping)
        if re.match(POPUPS, eid):
            for x in e.iter():
                if POPUP in (x.get("style") or ""):
                    set_style(x, fill_opacity=f"{POPUP_ALPHA:g}", opacity="1")

    # 2. sélection inactive : copie de la sélection, adoucie ; de même pour la vue qui garde le
    #    focus dans une fenêtre inactive (sans pièce -inactive, Kvantum y laisserait l'accent plein)
    for eid, e in list(ids.items()):
        for state in ("toggled", "pressed"):
            if re.match(rf"^itemview-{state}{PARTS}$", eid):
                parents[e].append(renamed(e, eid.replace(f"itemview-{state}", f"itemview-{state}-inactive"),
                                          {SELECTION: SELECTION_INACTIVE},
                                          (f"itemview-{state}", f"itemview-{state}-inactive")))

    # bouton par défaut des dialogues (OK, Enregistrer…) : Kvantum pose « button-default »
    # par-dessus l'état du bouton ; un voile teal le distingue, comme l'action suggérée de GNOME,
    # et laisse voir le survol (texte clair : Kvantum n'a pas de couleur de texte pour lui)
    for eid, e in list(ids.items()):
        if re.match(rf"^button-normal{PARTS}$", eid):
            tint = renamed(e, eid.replace("button-normal", "button-default"), {"#414141": TEAL, "#444444": TEAL},
                           ("button-normal", "button-default"))
            if not tint.tag.endswith("use"):  # un <use> reprend déjà l'opacité de sa pièce
                set_style(tint, opacity=str(DEFAULT_TINT))
            parents[e].append(tint)

    # 3. pièces expand- (rayon sans changer les marges), dont l'anneau de focus des champs,
    #    affiné pour rester à 2 px une fois le coin agrandi
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    parents = {c: p for p in root.iter() for c in p}
    for eid, e in list(ids.items()):
        m = re.match(rf"^({'|'.join(EXPAND)})-(normal|focused|pressed|toggled|disabled|default)(-inactive)?{PARTS}$", eid)
        if m:
            base = "-".join(x for x in (m.group(1), m.group(2)) if x) + (m.group(3) or "")
            copy_ = renamed(e, "expand-" + eid, prefix=(base, "expand-" + base))
            if m.group(1) in ("lineedit", "combo") and m.group(2) == "focused" and m.group(5):
                thin_ring(copy_, m.group(5), 6 / EXPAND[m.group(1)][1])
            parents[e].append(copy_)

    # anneau de focus : les pièces de celui des champs, sous le nom que Kvantum cherche
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    parents = {c: p for p in root.iter() for c in p}
    for ring in ("lineedit-focused", "expand-lineedit-focused"):
        for eid, e in list(ids.items()):
            m = re.match(rf"^{ring}(-(?:top|bottom|left|right|topleft|topright|bottomleft|bottomright))$", eid)
            if m:
                for target in FOCUS_FRAMES:
                    new = ring.replace("lineedit-focused", f"{target}-focus")
                    frame = renamed(e, new + m.group(1), prefix=(ring, new))
                    for x in frame.iter():  # le trait seul : le fond des champs resterait sur le bouton
                        if (x.tag.endswith(("rect", "path")) and "ColorScheme-Highlight" not in (x.get("class") or "")
                                and "opacity:0.15" not in (x.get("style") or "")):
                            set_style(x, opacity="0")
                    parents[e].append(frame)

    # fenêtre inactive : les accents s'éteignent, l'interface recule
    grey = {"#3584e4": INACTIVE_ACCENT, "#4990e7": INACTIVE_ACCENT, TEAL: INACTIVE_ACCENT}
    for eid, e in list(ids.items()):
        m = re.match(rf"^((?:checkbox|radio)-(?:checked|tristate)-(?:normal|focused)|progress-pattern-normal"
                     rf"|slider-toggled|button-default){PARTS}$", eid)
        if m and not eid.endswith("-inactive"):
            base, part = m.group(1), m.group(2) or ""
            parents[e].append(renamed(e, f"{base}-inactive{part}", grey, (base, f"{base}-inactive")))

    # 4. le reste, par la table générale
    out = ET.tostring(root, encoding="unicode")
    return HEX.sub(lambda m: SVG_COLORS.get(m.group(0).lower(), m.group(0)), out)


RING = re.compile(r"m (\S+),(\S+) c (\S+),(\S+) (\S+),(\S+) (\S+),(\S+) ([hv]) (\S+) "
                  r"c (\S+),(\S+) (\S+),(\S+) (\S+),(\S+) z")


def renamed(e, new_id, colors=None, prefix=None):
    """Copie d'un élément sous un autre nom (et ses sous-éléments, pour garder des id uniques).
    Beaucoup de pièces de KvLibadwaita sont des <use> d'un coin ou d'un bord : prefix = (ancien,
    nouveau) les fait pointer vers les pièces copiées."""
    c = copy.deepcopy(e)
    for x in c.iter():
        if x.get("id"):
            x.set("id", f"{new_id}-{x.get('id')}")
        for k, v in list(x.attrib.items()):
            if prefix and k.endswith("href") and v.startswith("#" + prefix[0] + "-"):
                x.set(k, "#" + prefix[1] + v[1 + len(prefix[0]):])
    c.set("id", new_id)
    if colors:
        recolor_attrs(c, colors)
    return c


def thin_ring(e, part, k):
    """L'anneau fait 2 px dans un coin de 6 : agrandi au rayon voulu, il grossirait d'autant.
    On l'affine dans la même proportion k, en gardant son bord extérieur : les bords sont des
    bandes collées au côté extérieur (retournées pour bas et droite), les coins un arc
    extérieur, un trait de la largeur de l'anneau puis un arc intérieur."""
    for x in e.iter():
        if "ColorScheme-Highlight" not in (x.get("class") or "") and "opacity:0.15" not in (x.get("style") or ""):
            continue
        if x.tag.endswith("rect"):
            attr = "height" if part in ("top", "bottom") else "width"
            x.set(attr, f"{float(x.get(attr)) * k:.6f}")
        elif x.tag.endswith("path"):
            m = RING.fullmatch(x.get("d").strip())
            if not m:
                raise SystemExit(f"anneau de focus inattendu : {e.get('id')}")
            v = [float(n) if n not in "hv" else n for n in m.groups()]
            outer, w = abs(v[6]), v[9]
            inner = (outer - abs(w * k)) / (outer - abs(w))  # arc intérieur : rayon plus grand
            arc = " ".join(f"{v[i] * inner:.6f},{v[i + 1] * inner:.6f}" for i in (10, 12, 14))
            x.set("d", f"m {v[0]},{v[1]} c {v[2]},{v[3]} {v[4]},{v[5]} {v[6]},{v[7]} "
                       f"{v[8]} {w * k:.6f} c {arc} z")


def build_kvconfig(text):
    out, section, seen = [], None, {}
    for line in text.splitlines():
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            out.extend(missing(section, seen))
            section, seen = m.group(1), {}
            out.append(line)
            continue
        if "=" in line and section:
            key, value = (s.strip() for s in line.split("=", 1))
            seen[key] = True
            if section == "GeneralColors" and key in GENERAL_COLORS:
                value = GENERAL_COLORS[key]
            elif key in SETTINGS.get(section, {}):
                value = SETTINGS[section][key]
            elif re.match(r"^text\.(normal|focus|press|toggle)(\.inactive)?\.color$", key):
                value = TEXT
            line = f"{key}={value}"
        out.append(line)
    out.extend(missing(section, seen))
    return "\n".join(out) + "\n"


def missing(section, seen):
    wanted = {**SETTINGS.get(section, {})}
    if section == "GeneralColors":
        wanted.update(GENERAL_COLORS)
    return [f"{k}={v}" for k, v in wanted.items() if k not in seen]


def main():
    src, dst, name = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    dst.mkdir(parents=True, exist_ok=True)
    (dst / f"{name}.svg").write_text(build_svg((src / "KvLibadwaitaDark.svg").read_text()))
    (dst / f"{name}.kvconfig").write_text(build_kvconfig((src / "KvLibadwaitaDark.kvconfig").read_text()))


if __name__ == "__main__":
    main()
