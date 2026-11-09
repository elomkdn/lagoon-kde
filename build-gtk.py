#!/usr/bin/env python3
"""Construit le thème GTK « Lagoon » : le style de libadwaita (adw-gtk3 v6.5 pour les
applis GTK 3 et GTK 4, libadwaita lui-même pour les applis GNOME) aux couleurs de la palette
officielle de Catppuccin Mocha, accent teal.

Les couleurs suivent les rôles du jeu de couleurs KDE et du style Kvantum, pour que les applis
GTK ressemblent aux applis Qt et Kirigami : le cadre (fenêtres, barres d'en-tête et latérales,
dialogues) en mantle, le contenu (vues, listes encadrées) et les popups (menus, popovers,
infobulles) en base, le texte en text ; les sélections en teal avec un texte sombre, plus
douces en fenêtre inactive ; les boutons de fenêtre en pastilles rouge, jaune et verte, comme
la décoration Catppuccin Mocha Classic. Les widgets reprennent aussi les choix du style
Kvantum : boutons en graisse normale, bouton d'action suggérée voilé de teal comme le bouton
par défaut, onglets en pastille, menus aux coins de 9 px ; poignées des curseurs et
interrupteurs en text, comme dans Plasma ; OSD en crust. Le fond des boutons reste le voile
de libadwaita (10 % du texte) : une règle générale sur les boutons, chargée par les applis
libadwaita avec la priorité du CSS utilisateur, passerait devant les boutons plats et ceux
que les applis colorent elles-mêmes.

adw-gtk3 et libadwaita nomment leurs couleurs (@define-color window_bg_color…) : il suffit de
les redéfinir après leur feuille de style. Les widgets sont redessinés avec leurs propres
sélecteurs, relevés dans leurs feuilles de style : même spécificité, et les nôtres viennent
après. Les applis libadwaita ignorent le thème GTK : elles lisent gtk-4.0/lagoon.css par
~/.config/gtk-4.0/gtk.css (install.sh), où ses règles l'emportent sur celles de libadwaita.

usage : build-gtk.py <dossier d'adw-gtk3> <dossier des thèmes> <nom>
"""
import re
import shutil
import sys
from pathlib import Path

# Catppuccin Mocha, palette officielle (github.com/catppuccin/palette)
CRUST, MANTLE, BASE, SURFACE0, TEXT = "#11111b", "#181825", "#1e1e2e", "#313244", "#cdd6f4"
TEAL, RED, YELLOW, GREEN = "#94e2d5", "#f38ba8", "#f9e2af", "#a6e3a1"


def mix(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def channels(color):
    return [str(int(color[i:i + 2], 16)) for i in (1, 3, 5)]


def alpha(color, a):
    return f"rgba({', '.join(channels(color))}, {a})"


# Couleurs nommées d'adw-gtk3 et de libadwaita -> Mocha ; ombres et filets en crust, aux
# opacités de libadwaita
COLORS = {
    # accent et états, avec un texte sombre dessus, comme dans les applis KDE
    "accent_bg_color": TEAL, "accent_fg_color": CRUST, "accent_color": TEAL,
    "destructive_bg_color": RED, "destructive_fg_color": CRUST, "destructive_color": RED,
    "success_bg_color": GREEN, "success_fg_color": CRUST, "success_color": GREEN,
    "warning_bg_color": YELLOW, "warning_fg_color": CRUST, "warning_color": YELLOW,
    "error_bg_color": RED, "error_fg_color": CRUST, "error_color": RED,
    # le cadre en mantle, comme le fond des fenêtres et les barres d'outils des applis Qt
    "window_bg_color": MANTLE, "window_fg_color": TEXT,
    "headerbar_bg_color": MANTLE, "headerbar_fg_color": TEXT, "headerbar_border_color": TEXT,
    "headerbar_backdrop_color": MANTLE, "headerbar_shade_color": alpha(CRUST, 0.36),
    "headerbar_darker_shade_color": alpha(CRUST, 0.9),
    "sidebar_bg_color": MANTLE, "sidebar_fg_color": TEXT, "sidebar_backdrop_color": MANTLE,
    "sidebar_shade_color": alpha(CRUST, 0.25), "sidebar_border_color": alpha(CRUST, 0.36),
    "secondary_sidebar_bg_color": MANTLE, "secondary_sidebar_fg_color": TEXT,
    "secondary_sidebar_backdrop_color": MANTLE, "secondary_sidebar_shade_color": alpha(CRUST, 0.25),
    "secondary_sidebar_border_color": alpha(CRUST, 0.36),
    "dialog_bg_color": MANTLE, "dialog_fg_color": TEXT,
    # le contenu en base : vues, listes encadrées (comme les cartes de Kirigami), vignettes
    "view_bg_color": BASE, "view_fg_color": TEXT,
    "card_bg_color": BASE, "card_fg_color": TEXT, "card_shade_color": alpha(CRUST, 0.36),
    "thumbnail_bg_color": BASE, "thumbnail_fg_color": TEXT,
    # popups en base, comme ceux de Plasma et les menus des applis Qt
    "popover_bg_color": BASE, "popover_fg_color": TEXT, "popover_shade_color": alpha(CRUST, 0.25),
    "shade_color": alpha(CRUST, 0.25), "scrollbar_outline_color": alpha(CRUST, 0.95),
}
SELECTION_BACKDROP = mix(TEAL, BASE, 0.4)  # fenêtre inactive : le teal adouci de Kvantum
# Action suggérée : le bouton par défaut de Kvantum, un bouton voilé de teal à 25 %, texte clair
# (Kvantum n'a pas de couleur de texte pour le bouton par défaut : un teal plein y serait illisible)
SUGGESTED = mix(SURFACE0, TEAL, 0.25)
# boutons de fenêtre, comme la décoration Catppuccin ; inactifs en surface0, glyphe en base
WINDOW_BUTTONS = {"close": RED, "minimize": YELLOW, "maximize": GREEN}
# Pastilles de Klassy mesurées avec extras/klassy/klassyrc et Inter 12 : Klassy calcule leur taille
# d'après la police de la barre de titre, à refaire si elle change. Écarts propres à GTK : 6 px
# entre les boutons de GTK 3 (espacement de la headerbar) ; 4 px de marge intérieure en GTK 4.
WINDOW_BUTTON_SIZE = 17
WINDOW_BUTTON_PITCH = 29
GTK3_BUTTON_MARGIN = (WINDOW_BUTTON_PITCH - WINDOW_BUTTON_SIZE - 6) // 2
GTK4_BUTTON_PADDING = 4

# Sélecteurs de sélection à laisser tels quels : menus (ils gardent leur surlignage), OSD,
# onglets, boutons, barres de progression, glisser-déposer, champs en erreur, applis particulières
KEEP = re.compile(r"popover|menu|\.osd|tabbar|calendar|button|progressbar|trough|dnd|separator|badge|"
                  r"chromium|Mozilla|terminal|nemo|caja|geary|gnc-id|wnck|content-view|:drop|\.error|"
                  r"\.warning|infobar|print|dialog-host|source-list")
OSD = re.compile(r"\.osd|app-notification|touch-selection|magnifier")
KNOB = re.compile(r"(scale|switch)[^,]*slider")


def rules(css):
    return re.findall(r"([^{}@]+)\{([^{}]*)\}", re.sub(r"/\*.*?\*/", "", css, flags=re.S))


def split(selector):
    return [" ".join(x.split()) for x in selector.split(",")]


def plain(selector):
    return re.sub(r":not\([^)]*\)", "", selector)


def rule(selectors, *declarations):
    return ",\n".join(selectors) + " {\n" + "".join(f"  {d};\n" for d in declarations) + "}\n"


def selections(css):
    """Lignes, éléments et textes sélectionnés auxquels la feuille donne un fond ou une couleur :
    teal et texte sombre, teal adouci en fenêtre inactive."""
    found = []
    for selector, body in rules(css):
        if re.search(r"(?<![-\w])(background(-color)?|color)\s*:", body):
            for s in split(selector):
                if ((":selected" in plain(s) or re.search(r"(^|[\s>])selection\b", plain(s)))
                        and not KEEP.search(s) and s not in found):
                    found.append(s)
    active = [s for s in found if ":backdrop" not in s]
    backdrop = [s for s in found if ":backdrop" in s] + [f"{s}:backdrop" for s in active]
    return (rule(active, f"background-color: {TEAL}", f"color: {CRUST}")
            + rule(backdrop, f"background-color: {SELECTION_BACKDROP}", f"color: {CRUST}"))


def menu_rows(css):
    """Dans les menus de libadwaita, une ligne « sélectionnée » est celle du clavier : leurs règles
    de fond sont rejouées après les sélections, et le texte garde sa couleur."""
    out = []
    for selector, body in rules(css):
        selectors = split(selector)
        if any(re.search(r"popover\.menu (list|listview) > row", s) for s in selectors):
            backgrounds = [d.strip() for d in body.split(";") if re.match(r"\s*background(-color)?\s*:", d)]
            if backgrounds:
                out.append(rule(selectors, *backgrounds))
    return "".join(out) + rule(["popover.menu list > row:selected", "popover.menu listview > row:selected"],
                               "color: inherit")


def regular_buttons(css):
    """libadwaita écrit le texte des boutons en gras ; Qt, Kirigami et Plasma non."""
    found = []
    for selector, body in rules(css):
        if re.search(r"font-weight:\s*(bold|[6-9]00)", body):
            found += [s for s in split(selector) if "button" in s and not re.search(r"tabbutton|\.title|heading", s)
                      and s not in found]
    return rule(found, "font-weight: normal") if found else ""


def tabs(css, checked):
    """Onglets en pastille, comme ceux de Kvantum : pas de trait sous l'onglet actif, mais un fond
    du ton des boutons."""
    out = []
    for selector, body in rules(css):
        selectors = [s for s in split(selector) if re.search(r"notebook > header(\.\w+)? > tabs > tab", s)]
        if selectors and re.search(r"box-shadow:\s*inset", body):
            out.append(rule(selectors, "box-shadow: none"))
    sides = [f"notebook > header.{side} > tabs > tab:checked" for side in ("top", "bottom", "left", "right")]
    return "".join(out) + rule(["notebook > header > tabs > tab"], "border-radius: 9px") + rule(sides, checked)


def recolored(css, select, replace):
    """Rejoue les déclarations des règles retenues par select, couleurs remplacées par replace."""
    out = []
    for selector, body in rules(css):
        selectors = [s for s in split(selector) if select(s)]
        if not selectors:
            continue
        declarations = [replace(d.strip()) for d in body.split(";")
                        if re.match(r"\s*(background(-color)?|color|border-color)\s*:", d)]
        changed = [d for d in declarations if d not in [x.strip() for x in body.split(";")]]
        if changed:
            out.append(rule(selectors, *changed))
    return "".join(out)


def osd4(declaration):
    declaration = re.sub(r"RGB\(0 0 0 ?/ ?(\d+)%\)", rf"rgb({' '.join(channels(CRUST))} / \1%)", declaration)
    return re.sub(r"RGB\(255 255 255 ?/ ?(\d+)%\)", rf"rgb({' '.join(channels(TEXT))} / \1%)", declaration)


def osd3(declaration):
    declaration = re.sub(r"rgba\(0, 0, 0,", f"rgba({', '.join(channels(CRUST))},", declaration)
    declaration = re.sub(r"rgba\(255, 255, 255,", f"rgba({', '.join(channels(TEXT))},", declaration)
    return re.sub(r"(?<![-\w])color:\s*white\b", f"color: {TEXT}", declaration)


def knob(declaration):
    """Poignée : le blanc de libadwaita, au repos un peu mêlé au fond, devient text."""
    if not declaration.startswith("background"):
        return declaration
    declaration = re.sub(r"color-mix\(in srgb, white \d+%, var\(--view-bg-color\)\)", TEXT, declaration)
    declaration = re.sub(r"mix\(white,@view_bg_color,0\.\d+\)", TEXT, declaration)
    return re.sub(r"\bwhite\b", TEXT, declaration)


def accent_text(css):
    """adw-gtk3 écrit en blanc sur l'accent (sélection des terminaux…) : illisible sur le teal
    pastel de Mocha. Ce texte prend la couleur prévue pour l'accent."""
    def fix(m):
        selector, body = m.group(1), m.group(2)
        if "accent_bg_color" in body and ".osd" not in selector:
            body = re.sub(r"(?<![-\w])color:\s*white\b", "color: @accent_fg_color", body)
            body = re.sub(r"(?<![-\w])color:\s*alpha\(white,", "color: alpha(@accent_fg_color,", body)
        return f"{selector}{{{body}}}"
    return re.sub(r"([^{}]+)\{([^{}]*)\}", fix, css)


def suggested_veil(css):
    """GTK 3 : les boutons d'action suggérée prennent le voile teal de Kvantum (SUGGESTED) et un
    texte clair, au lieu de l'accent plein."""
    def fix(m):
        selector, body = m.group(1), m.group(2)
        selectors = split(re.sub(r"/\*.*?\*/", "", selector, flags=re.S))
        if all(".suggested-action" in s and ".flat" not in s and not OSD.search(s) for s in selectors if s):
            body = body.replace("@accent_bg_color", "@suggested_bg_color").replace("@accent_fg_color", "@window_fg_color")
            body = re.sub(r"(?<![-\w])color:\s*white\b", "color: @window_fg_color", body)
            body = re.sub(r"(?<![-\w])color:\s*alpha\(white,", "color: alpha(@window_fg_color,", body)
        return f"{selector}{{{body}}}"
    return re.sub(r"([^{}]+)\{([^{}]*)\}", fix, css)


def qt_button_tones(css):
    """GTK 3 buttons in surface0, the tone of Qt and Plasma buttons, instead of adw-gtk3's
    10 % of text over the window's mantle; a step lighter on hover. (GTK 4 buttons stay
    libadwaita's: libadwaita apps read our sheet with the priority of user sheets, where a
    rule for every button would override flat buttons and the apps that color their own.)"""
    return (css.replace("mix(@window_fg_color,@window_bg_color,0.9)", SURFACE0)
               .replace("mix(@window_fg_color,@window_bg_color,0.85)", mix(SURFACE0, TEXT, 0.07)))


def gtk3_css(adw):
    out = ["\n/* Lagoon: the official Catppuccin Mocha palette, teal accent */\n"]
    out += [f"@define-color {name} {value};\n" for name, value in COLORS.items()]
    out.append(f"@define-color suggested_bg_color {SUGGESTED};\n")
    out.append("\n/* selections: teal with dark text, as in KDE apps; softer in inactive windows */\n")
    out.append(selections(adw))
    out.append("\n/* buttons, tabs and menus as in Qt apps (Kvantum) */\n")
    out.append(regular_buttons(adw))
    out.append(tabs(adw, "background-color: alpha(currentColor, 0.15)"))
    out.append(rule([".csd popover.background.menu", "popover.background.menu"], "border-radius: 9px"))
    out.append("\n/* slider and switch knobs in Mocha text, as in Plasma; on-screen displays in crust */\n")
    out.append(recolored(adw, lambda s: KNOB.search(s) and not OSD.search(s), knob))
    # activé, une ombre détache le rond clair du teal, qui a presque la même luminosité
    out.append(rule([f"switch:checked{state} slider" for state in ("", ":hover", ":active", ":backdrop")],
                    "box-shadow: 0 0 0 1px rgba(17, 17, 27, 0.55), 0 1px 3px rgba(17, 17, 27, 0.6)"))
    out.append(recolored(adw, OSD.search, osd3))
    out.append("\n/* tooltips: opaque, in Mocha base like Plasma's */\n")
    out.append(rule(["tooltip"], "text-shadow: none"))
    out.append(rule(["tooltip.background"], f"background-color: {BASE}", f"border-color: {SURFACE0}"))
    out.append(rule(["tooltip *"], f"color: {TEXT}"))
    out.append("\n/* window buttons: red, yellow and green dots like the Catppuccin decoration, glyph on hover */\n")
    # adw-gtk3 colore le texte des boutons des barres de titre avec « .titlebar:not(.selection-mode)
    # button:not(…):not(…) » : les mêmes contextes, et une classe de plus, pour passer devant
    contexts = (".titlebar button.titlebutton{}:not(.appmenu)", "headerbar button.titlebutton{}:not(.appmenu)")
    out.append(rule([c.format(f".{b}") for b in WINDOW_BUTTONS for c in contexts],
                    f"min-width: {WINDOW_BUTTON_SIZE}px", f"min-height: {WINDOW_BUTTON_SIZE}px",
                    f"margin: 0 {GTK3_BUTTON_MARGIN}px", "color: transparent"))
    for button, color in WINDOW_BUTTONS.items():
        out.append(rule([c.format(f".{button}") for c in contexts], f"background-color: {color}"))
    out.append(rule([c.format(":hover") for c in contexts], f"color: {BASE}"))
    out.append(rule([c.format(":active") for c in contexts], f"box-shadow: inset 0 0 0 9px {alpha(CRUST, 0.2)}"))
    out.append(rule([c.format(":backdrop:not(:hover)") for c in contexts], f"background-color: {SURFACE0}"))
    return "".join(out)


def gtk4_css(adw):
    out = ["/* Lagoon: the official Catppuccin Mocha palette, teal accent, on the libadwaita style.\n"
           "   Imported by the GTK 4 theme, and by ~/.config/gtk-4.0/gtk.css for libadwaita apps. */\n"]
    out.append("@media (prefers-color-scheme: dark) {\n")
    out += [f"@define-color {name} {value};\n" for name, value in COLORS.items()]
    out.append("\n/* libadwaita takes the system's accent, rounded to one of its own */\n")
    out.append(rule([":root"], f"--accent-bg-color: {TEAL}", f"--accent-fg-color: {CRUST}"))
    out.append("\n/* selections: teal with dark text, as in KDE apps; softer in inactive windows */\n")
    out.append(selections(adw))
    out.append(menu_rows(adw))
    out.append("\n/* buttons, tabs and menus as in Qt apps (Kvantum) */\n")
    out.append(regular_buttons(adw))
    out.append(rule([".suggested-action"], f"--accent-bg-color: {SUGGESTED}", f"--accent-fg-color: {TEXT}"))
    out.append(tabs(adw, "background-color: color-mix(in srgb, currentColor 15%, transparent)"))
    out.append(rule(["popover.menu > contents", "popover.menu > arrow",
                     "menubar > item popover.menu popover.menu > contents"], "border-radius: 9px"))
    out.append("\n/* slider and switch knobs in Mocha text, as in Plasma; on-screen displays in crust */\n")
    out.append(recolored(adw, lambda s: KNOB.search(s) and not re.search(r"scale\.color|\.osd", s), knob))
    out.append(rule([f"switch:checked{state} > slider" for state in ("", ":hover", ":active", ":backdrop")],
                    "box-shadow: 0 0 0 1px rgba(17, 17, 27, 0.55), 0 1px 3px rgba(17, 17, 27, 0.6)"))
    out.append(recolored(adw, OSD.search, osd4))
    out.append("\n/* tooltips: opaque, in Mocha base like Plasma's */\n")
    out.append(rule(["tooltip.background"], f"background-color: {BASE}", f"color: {TEXT}",
                    f"border-color: {SURFACE0}"))
    out.append("\n/* window buttons: red, yellow and green dots like the Catppuccin decoration, glyph on hover */\n")
    out.append(rule(["windowcontrols"],
                    f"border-spacing: {WINDOW_BUTTON_PITCH - WINDOW_BUTTON_SIZE - 2 * GTK4_BUTTON_PADDING}px"))
    out.append(rule(["windowcontrols > button"], f"min-width: {WINDOW_BUTTON_SIZE}px",
                    f"padding: {GTK4_BUTTON_PADDING}px"))
    out.append(rule(["windowcontrols > button > image", "headerbar.default-decoration windowcontrols > button > image"],
                    f"-gtk-icon-size: {WINDOW_BUTTON_SIZE - 4}px", "padding: 2px", "box-shadow: none", "color: transparent"))
    for button, color in WINDOW_BUTTONS.items():
        out.append(rule([f"windowcontrols > button.{button} > image"], f"background-color: {color}"))
    out.append(rule(["windowcontrols > button:hover > image"], f"color: {BASE}"))
    out.append(rule(["windowcontrols > button:active > image"], f"box-shadow: inset 0 0 0 9px {alpha(CRUST, 0.2)}"))
    out.append(rule(["windowcontrols > button:backdrop:not(:hover) > image"], f"background-color: {SURFACE0}"))
    out.append("}\n")
    return "".join(out)


INDEX = """[Desktop Entry]
Type=X-GNOME-Metatheme
Name={name}
Comment=Catppuccin Mocha with the teal accent, in the libadwaita style (adw-gtk3)
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme={name}
CursorTheme=catppuccin-mocha-teal-cursors
ButtonLayout=close,minimize,maximize:
"""


def main():
    src, themes, name = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    dst = themes / name
    shutil.rmtree(dst, ignore_errors=True)
    for gtk in ("gtk-3.0", "gtk-4.0"):
        shutil.copytree(src / gtk, dst / gtk)
    (dst / "index.theme").write_text(INDEX.format(name=name))

    # GTK 3 : la feuille d'adw-gtk3, puis la palette et les surcharges
    gtk3 = dst / "gtk-3.0" / "gtk.css"
    adw = qt_button_tones(accent_text(suggested_veil(gtk3.read_text())))
    gtk3.write_text(adw + gtk3_css(adw))
    # GTK 4 sans libadwaita : la feuille de libadwaita d'adw-gtk3, ses retouches, puis les nôtres
    (dst / "gtk-4.0" / "lagoon.css").write_text(gtk4_css((src / "gtk-4.0" / "libadwaita.css").read_text()))
    (dst / "gtk-4.0" / "gtk.css").write_text(
        "".join(f'@import url("{f}");\n' for f in ("libadwaita.css", "libadwaita-tweaks.css", "lagoon.css")))
    # thème sombre seulement : la variante sombre que GTK préfère est la même
    for gtk in ("gtk-3.0", "gtk-4.0"):
        (dst / gtk / "gtk-dark.css").write_text('@import url("gtk.css");\n')


if __name__ == "__main__":
    main()
