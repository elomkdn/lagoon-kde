#!/usr/bin/env python3
"""Galerie de widgets GTK rendue hors écran, le pendant de kvgallery pour les applis GTK : les
mêmes widgets (boutons, champs, cases, curseur, onglets, liste avec sélection, menu, infobulle,
champ avec le focus), plus ceux propres à GTK (barre d'en-tête, barre latérale, interrupteurs,
action destructive, liste encadrée), dans une seule image. Les fenêtres s'ouvrent sur un
serveur Broadway privé : rien ne s'affiche à l'écran.

usage : gtkgallery.py <gtk3|gtk4|adw> <dossier de données> <thème> <sortie.png> [CSS utilisateur]
  gtk3, gtk4  applis GTK 3 ou GTK 4 avec le thème <dossier de données>/themes/<thème>
  adw         applis libadwaita : elles ignorent le thème GTK, seul le CSS utilisateur les colore
  CSS utilisateur  joué comme ~/.config/gtk-<3|4>.0/gtk.css (avec le colors.css de KDE posé à côté)
ex. : gtkgallery.py adw ~/.local/share Lagoon adw.png ~/.config/gtk-4.0/gtk.css
"""
import base64
import configparser
import os
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path

PAD = 16       # marge autour de chaque capture
WAIT = 700     # ms : laisser finir les transitions (focus, survol) avant une capture
BACKGROUND = "#11111b"
# réglages du bureau repris tels quels : police, icônes, boutons de fenêtre
SETTINGS = ("gtk-font-name", "gtk-icon-theme-name", "gtk-decoration-layout", "gtk-xft-dpi",
            "gtk-xft-antialias", "gtk-xft-hinting", "gtk-xft-hintstyle", "gtk-xft-rgba")


def launch(mode, data, theme, out, user_css=None):
    gtk = "gtk-3.0" if mode == "gtk3" else "gtk-4.0"
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    desktop = configparser.ConfigParser(interpolation=None, strict=False)
    desktop.optionxform = str
    desktop.read(config / gtk / "settings.ini")
    settings = {k: v for k, v in desktop["Settings"].items() if k in SETTINGS} if desktop.has_section("Settings") else {}
    # sans animations, chaque capture montre l'état final (focus, survol)
    settings.update({"gtk-theme-name": theme, "gtk-application-prefer-dark-theme": "true",
                     "gtk-enable-animations": "false"})

    with tempfile.TemporaryDirectory() as cfg:
        conf = Path(cfg) / gtk
        conf.mkdir()
        (conf / "settings.ini").write_text("[Settings]\n" + "".join(f"{k}={v}\n" for k, v in settings.items()))
        if user_css:
            shutil.copyfile(user_css, conf / "gtk.css")
            for name in ("colors.css", "assets"):  # fichiers que le CSS utilisateur peut référencer
                if Path(user_css).with_name(name).exists():
                    (conf / name).symlink_to(Path(user_css).with_name(name).resolve())

        display = free_display()
        server = subprocess.Popen(["broadwayd" if mode == "gtk3" else "gtk4-broadwayd", "--address", "127.0.0.1",
                                   f":{display}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            wait_for_port(8080 + display)
            if mode == "gtk3":  # sans navigateur connecté, l'écran fait 0 × 0 et les menus GTK 3 s'écrasent
                set_screen_size(8080 + display, [ord("d"), 0, 0, 1920, 1080])
            env = {k: v for k, v in os.environ.items()
                   if not k.startswith(("GTK_", "GDK_", "GSK_")) and k not in ("DISPLAY", "WAYLAND_DISPLAY")}
            env.update(GDK_BACKEND="broadway", BROADWAY_DISPLAY=f":{display}", XDG_CONFIG_HOME=cfg,
                       XDG_DATA_HOME=str(Path(data).expanduser().resolve()), NO_AT_BRIDGE="1")
            subprocess.run([sys.executable, "-I", os.path.realpath(__file__), "--render", mode,
                            str(Path(out).resolve())], env=env, check=True)
        finally:
            server.terminate()
            server.wait()


def free_display():
    for display in range(40, 100):  # Broadway écoute aussi en HTTP, sur le port 8080 + n
        with socket.socket() as s:
            try:
                s.bind(("127.0.0.1", 8080 + display))
            except OSError:
                continue
        return display
    raise SystemExit("aucun port libre pour Broadway")


def wait_for_port(port):
    for _ in range(50):
        with socket.socket() as s:
            if s.connect_ex(("127.0.0.1", port)) == 0:
                return
        time.sleep(0.1)
    raise SystemExit("le serveur Broadway ne répond pas")


def set_screen_size(port, message):
    """Se connecte comme le ferait un navigateur, le temps de donner la taille de l'écran
    (message « taille d'écran » du broadway.js de GTK 3 : entiers 32 bits gros-boutistes)."""
    with socket.create_connection(("127.0.0.1", port)) as s:
        key = base64.b64encode(os.urandom(16)).decode()
        s.sendall(f"GET /socket HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                  f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: broadway\r\n\r\n"
                  .encode())
        reply = b""
        while b"\r\n\r\n" not in reply:
            reply += s.recv(4096)
        payload = struct.pack(f">{len(message)}i", *message)
        mask = os.urandom(4)  # trame binaire masquée, comme toutes celles d'un client WebSocket
        s.sendall(bytes([0x82, 0x80 | len(payload)]) + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))
        time.sleep(0.3)


def render_gtk4(adw, out):
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Gdk", "4.0")
    gi.require_version("Gsk", "4.0")
    gi.require_version("Graphene", "1.0")
    from gi.repository import Gdk, Gio, GLib, Graphene, Gsk, Gtk
    if adw:
        gi.require_version("Adw", "1")
        from gi.repository import Adw
        Adw.init()
        Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.FORCE_DARK)
    else:
        Gtk.init()
        # GTK ≥ 4.20 suit la préférence sombre que donne le portail de Plasma ; Broadway n'en a pas
        if hasattr(Gtk, "InterfaceColorScheme"):
            Gtk.Settings.get_default().props.gtk_interface_color_scheme = Gtk.InterfaceColorScheme.DARK

    class Tooltip(Gtk.Box):  # même nœud CSS qu'une infobulle (tooltip.background)
        __gtype_name__ = "GalleryTooltip"
    Tooltip.set_css_name("tooltip")

    def wait(ms):
        loop = GLib.MainLoop()
        GLib.timeout_add(ms, loop.quit)
        loop.run()

    def box(vertical=False, spacing=8, *children, **props):
        b = Gtk.Box(orientation=Gtk.Orientation.VERTICAL if vertical else Gtk.Orientation.HORIZONTAL,
                    spacing=spacing, **props)
        for c in children:
            b.append(c)
        return b

    def listbox(rows, selected, css=None):
        lb = Gtk.ListBox()
        for text in rows:
            lb.append(Gtk.Label(label=text, xalign=0, margin_start=8, margin_end=8, margin_top=6, margin_bottom=6))
        lb.select_row(lb.get_row_at_index(selected))
        if css:
            lb.add_css_class(css)
        return lb

    menu = Gio.Menu()
    first = Gio.Menu()
    first.append("Ouvrir", "g.open")
    first.append("Renommer", "g.rename")
    second = Gio.Menu()
    second.append("Supprimer", "g.delete")
    menu.append_section(None, first)
    menu.append_section(None, second)
    actions = Gio.SimpleActionGroup()
    actions.add_action(Gio.SimpleAction.new("open", None))
    actions.add_action(Gio.SimpleAction.new_stateful("rename", None, GLib.Variant.new_boolean(True)))
    actions.add_action(Gio.SimpleAction.new("delete", None))

    default = Gtk.Button(label="Par défaut", css_classes=["suggested-action"])
    tool = Gtk.Button(label="Outil", css_classes=["flat"])
    buttons = box(False, 8, Gtk.Button(label="Bouton"), default, Gtk.ToggleButton(label="Activé", active=True),
                  Gtk.Button(label="Inactif", sensitive=False), tool)
    edit = Gtk.Entry(text="Texte")
    spin = Gtk.SpinButton.new_with_range(0, 100, 1)
    spin.set_value(42)
    fields = box(False, 8, edit, Gtk.Entry(placeholder_text="Rechercher…"),
                 Gtk.DropDown.new_from_strings(["Liste déroulante", "Deux"]), spin)
    r1 = Gtk.CheckButton(label="Choix 1", active=True)
    r2 = Gtk.CheckButton(label="Choix 2", group=r1)
    checks = box(False, 12, Gtk.CheckButton(label="Coché", active=True), Gtk.CheckButton(label="Décoché"), r1, r2)
    scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
    scale.set_value(60)
    tabs = Gtk.Notebook()
    group = Gtk.Frame(label="Groupe", child=Gtk.Label(label="Contenu d'un onglet, dans un cadre.", xalign=0,
                                                       margin_start=10, margin_end=10, margin_top=10, margin_bottom=10))
    tabs.append_page(box(True, 0, group, margin_start=8, margin_end=8, margin_top=8, margin_bottom=8),
                     Gtk.Label(label="Onglet actif"))
    tabs.append_page(Gtk.Box(), Gtk.Label(label="Autre"))
    left = box(True, 10, buttons, fields, checks, scale, Gtk.ProgressBar(fraction=0.45), tabs)

    files = listbox(["Documents", "Images (sélection)", "Musique", "Vidéos"], 1)
    sidebar = listbox(["Bureau", "Téléchargements (barre latérale)"], 1, "navigation-sidebar")
    inactive = listbox(["Musique", "Vidéos (fenêtre inactive)"], 1)
    switches = box(False, 8, Gtk.Switch(active=True, valign=Gtk.Align.CENTER), Gtk.Switch(valign=Gtk.Align.CENTER),
                   Gtk.Button(label="Supprimer", css_classes=["destructive-action"]))
    if adw:
        rows = [Adw.ActionRow(title="Ligne", subtitle="Sous-titre"), Adw.SwitchRow(title="Option", active=True)]
    else:
        rows = [box(False, 8, Gtk.Label(label="Option", hexpand=True, xalign=0),
                    Gtk.Switch(active=True), margin_start=12, margin_end=12, margin_top=8, margin_bottom=8)]
    boxed = Gtk.ListBox(selection_mode=Gtk.SelectionMode.NONE, css_classes=["boxed-list"])
    for r in rows:
        boxed.append(r)
    right = box(True, 10, Gtk.Frame(child=files), sidebar, Gtk.Frame(child=inactive), switches, boxed, hexpand=True)

    body = box(False, 16, left, right, margin_start=16, margin_end=16, margin_top=16, margin_bottom=16)
    header = (Adw.HeaderBar if adw else Gtk.HeaderBar)()
    header.pack_start(Gtk.Button(icon_name="go-previous-symbolic"))
    menu_button = Gtk.MenuButton(icon_name="open-menu-symbolic", menu_model=menu)
    header.pack_end(menu_button)
    win = (Adw.Window if adw else Gtk.Window)(title="Galerie")
    win.insert_action_group("g", actions)
    if adw:
        view = Adw.ToolbarView(content=body)
        view.add_top_bar(header)
        win.set_content(view)
    else:
        win.set_titlebar(header)
        win.set_child(body)

    tip = Tooltip(css_classes=["background"])
    tip.append(Gtk.Label(label="Une infobulle"))
    tip_win = Gtk.Window(decorated=False, child=box(False, 0, tip, margin_start=PAD, margin_top=PAD))

    renderer = Gsk.CairoRenderer.new()
    renderer.realize_for_display(Gdk.Display.get_default())

    def capture(widget):
        # après un changement d'état (focus, fenêtre inactive), GTK ne dessine le widget qu'une
        # fois sa nouvelle taille calculée, à une image suivante de l'horloge : on l'attend
        for _ in range(50):
            w, h = widget.get_width(), widget.get_height()
            snap = Gtk.Snapshot()
            Gtk.WidgetPaintable.new(widget).snapshot(snap, w, h)
            node = snap.to_node()
            if node is not None:
                return renderer.render_texture(node, Graphene.Rect().init(0, 0, w, h))
            widget.get_frame_clock().request_phase(Gdk.FrameClockPhase.LAYOUT)
            wait(100)
        renderer.unrealize()
        raise SystemExit(f"rien à capturer : {widget.get_css_name()} n'est pas affiché")

    win.present()
    tip_win.present()
    wait(WAIT)
    win.unset_state_flags(Gtk.StateFlags.BACKDROP)  # fenêtre active, comme à l'écran
    inactive.set_state_flags(Gtk.StateFlags.BACKDROP, False)
    files.get_row_at_index(1).grab_focus()
    wait(WAIT)
    shot = capture(win)

    menu_button.popup()
    wait(WAIT)
    popover = menu_button.get_popover()
    items = [w for w in descendants(popover) if w.get_css_name() == "modelbutton"]
    if items:
        items[0].set_state_flags(Gtk.StateFlags.PRELIGHT, False)  # premier élément survolé
    wait(WAIT)
    menu_shot = capture(popover)
    menu_button.popdown()
    tip_shot = capture(tip)
    edit.grab_focus()
    wait(WAIT)
    edit_shot = capture(edit)

    below = [menu_shot, tip_shot, edit_shot]
    width = max(shot.get_width(), sum(t.get_width() for t in below) + PAD * (len(below) + 1)) + 2 * PAD
    height = shot.get_height() + max(t.get_height() for t in below) + 3 * PAD
    bg = Gdk.RGBA()
    bg.parse(BACKGROUND)
    snap = Gtk.Snapshot()
    snap.append_color(bg, Graphene.Rect().init(0, 0, width, height))
    snap.append_texture(shot, Graphene.Rect().init(PAD, PAD, shot.get_width(), shot.get_height()))
    x = 2 * PAD
    for t in below:
        snap.append_texture(t, Graphene.Rect().init(x, shot.get_height() + 2 * PAD, t.get_width(), t.get_height()))
        x += t.get_width() + PAD
    renderer.render_texture(snap.to_node(), Graphene.Rect().init(0, 0, width, height)).save_to_png(out)
    renderer.unrealize()


def descendants(widget):
    child = widget.get_first_child()
    while child:
        yield child
        yield from descendants(child)
        child = child.get_next_sibling()


def render_gtk3(out):
    import gi
    gi.require_version("Gtk", "3.0")
    gi.require_version("Gdk", "3.0")
    import cairo
    from gi.repository import Gdk, GLib, Gtk

    class Tooltip(Gtk.Box):  # même nœud CSS qu'une infobulle (tooltip.background)
        __gtype_name__ = "GalleryTooltip3"
    Tooltip.set_css_name("tooltip")

    def wait(ms):
        loop = GLib.MainLoop()
        GLib.timeout_add(ms, loop.quit)
        loop.run()

    def box(vertical=False, spacing=8, *children, **props):
        b = Gtk.Box(orientation=Gtk.Orientation.VERTICAL if vertical else Gtk.Orientation.HORIZONTAL,
                    spacing=spacing, **props)
        for c in children:
            b.pack_start(c, False, False, 0)
        return b

    def styled(widget, *classes):
        for c in classes:
            widget.get_style_context().add_class(c)
        return widget

    def listbox(rows, selected, css=None):
        lb = Gtk.ListBox()
        for text in rows:
            lb.add(Gtk.Label(label=text, xalign=0, margin_start=8, margin_end=8, margin_top=6, margin_bottom=6))
        lb.select_row(lb.get_row_at_index(selected))
        return styled(lb, css) if css else lb

    buttons = box(False, 8, Gtk.Button(label="Bouton"), styled(Gtk.Button(label="Par défaut"), "suggested-action"),
                  Gtk.ToggleButton(label="Activé", active=True), Gtk.Button(label="Inactif", sensitive=False),
                  styled(Gtk.Button(label="Outil", relief=Gtk.ReliefStyle.NONE), "flat"))
    edit = Gtk.Entry(text="Texte")
    combo = Gtk.ComboBoxText()
    for t in ("Liste déroulante", "Deux"):
        combo.append_text(t)
    combo.set_active(0)
    spin = Gtk.SpinButton.new_with_range(0, 100, 1)
    spin.set_value(42)
    fields = box(False, 8, edit, Gtk.Entry(placeholder_text="Rechercher…"), combo, spin)
    r1 = Gtk.RadioButton.new_with_label_from_widget(None, "Choix 1")
    r2 = Gtk.RadioButton.new_with_label_from_widget(r1, "Choix 2")
    checks = box(False, 12, Gtk.CheckButton(label="Coché", active=True), Gtk.CheckButton(label="Décoché"), r1, r2)
    scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
    scale.set_value(60)
    scale.set_draw_value(False)
    tabs = Gtk.Notebook()
    group = Gtk.Frame(label="Groupe")
    group.add(Gtk.Label(label="Contenu d'un onglet, dans un cadre.", xalign=0, margin=10))
    tabs.append_page(box(True, 0, group, margin=8), Gtk.Label(label="Onglet actif"))
    tabs.append_page(Gtk.Box(), Gtk.Label(label="Autre"))
    left = box(True, 10, buttons, fields, checks, scale, Gtk.ProgressBar(fraction=0.45))
    left.pack_start(tabs, True, True, 0)

    files = listbox(["Documents", "Images (sélection)", "Musique", "Vidéos"], 1)
    files_frame = Gtk.Frame()
    files_frame.add(files)
    store = Gtk.ListStore(str)
    for t in ("Bureau", "Téléchargements (liste arborescente)", "Modèles"):
        store.append([t])
    tree = Gtk.TreeView(model=store, headers_visible=False)
    tree.append_column(Gtk.TreeViewColumn("Nom", Gtk.CellRendererText(), text=0))
    tree.get_selection().select_path(Gtk.TreePath(1))
    tree_frame = Gtk.Frame()
    tree_frame.add(tree)
    sidebar = listbox(["Bureau", "Téléchargements (barre latérale)"], 1, "navigation-sidebar")
    inactive = listbox(["Musique", "Vidéos (fenêtre inactive)"], 1)
    inactive_frame = Gtk.Frame()
    inactive_frame.add(inactive)
    switches = box(False, 8, Gtk.Switch(active=True, valign=Gtk.Align.CENTER), Gtk.Switch(valign=Gtk.Align.CENTER),
                   styled(Gtk.Button(label="Supprimer"), "destructive-action"))
    right = box(True, 10, files_frame, tree_frame, sidebar, inactive_frame, switches)

    body = box(False, 16, left, right, margin=16)
    header = Gtk.HeaderBar(title="Galerie", show_close_button=True)
    header.pack_start(Gtk.Button.new_from_icon_name("go-previous-symbolic", Gtk.IconSize.BUTTON))
    menu_button = Gtk.Button.new_from_icon_name("open-menu-symbolic", Gtk.IconSize.BUTTON)
    header.pack_end(menu_button)
    win = Gtk.Window()
    win.set_titlebar(header)
    win.add(body)

    menu = Gtk.Menu()
    items = [Gtk.MenuItem(label="Ouvrir"), Gtk.CheckMenuItem(label="Renommer", active=True),
             Gtk.SeparatorMenuItem(), Gtk.MenuItem(label="Supprimer")]
    for item in items:
        menu.append(item)
    menu.show_all()

    tip = styled(Tooltip(), "background")
    tip.pack_start(Gtk.Label(label="Une infobulle"), False, False, 0)
    tip_win = Gtk.Window(decorated=False)
    tip_win.add(box(False, 0, tip, margin=PAD))

    def capture(widget):
        surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, widget.get_allocated_width(), widget.get_allocated_height())
        widget.draw(cairo.Context(surface))
        return surface

    def crop(surface):
        """Retire la marge de l'ombre des fenêtres (décorations côté client) : garde les pixels opaques."""
        w, h = surface.get_width(), surface.get_height()
        alpha = bytes(surface.get_data())[3::4]  # ARGB32 en mémoire : B, G, R, A
        opaque = alpha.translate(bytes(1 if a > 200 else 0 for a in range(256)))
        rows = [y for y in range(h) if b"\x01" in opaque[y * w:(y + 1) * w]]
        if not rows:
            return surface
        left = min(opaque[y * w:(y + 1) * w].find(b"\x01") for y in rows)
        right = max(opaque[y * w:(y + 1) * w].rfind(b"\x01") for y in rows) + 1
        out = cairo.ImageSurface(cairo.FORMAT_ARGB32, right - left, rows[-1] + 1 - rows[0])
        cr = cairo.Context(out)
        cr.set_source_surface(surface, -left, -rows[0])
        cr.paint()
        return out

    win.show_all()
    tip_win.show_all()
    wait(WAIT)
    win.unset_state_flags(Gtk.StateFlags.BACKDROP)  # fenêtre active, comme à l'écran
    inactive.set_state_flags(Gtk.StateFlags.BACKDROP, False)
    files.get_row_at_index(1).grab_focus()
    wait(WAIT)
    shot = crop(capture(win))

    # popup_at_widget() demande un événement déclencheur et un écran : l'ancienne API place le menu
    menu.popup(None, None, lambda *args: (PAD, PAD, False), None, 0, 0)
    wait(WAIT)
    menu.select_item(items[0])  # premier élément survolé
    wait(WAIT)
    menu_shot = crop(capture(menu.get_toplevel()))
    menu.popdown()
    tip_shot = capture(tip)
    edit.grab_focus()
    wait(WAIT)
    edit_shot = capture(edit)

    below = [menu_shot, tip_shot, edit_shot]
    width = max(shot.get_width(), sum(s.get_width() for s in below) + PAD * (len(below) + 1)) + 2 * PAD
    height = shot.get_height() + max(s.get_height() for s in below) + 3 * PAD
    page = cairo.ImageSurface(cairo.FORMAT_ARGB32, width, height)
    cr = cairo.Context(page)
    bg = Gdk.RGBA()
    bg.parse(BACKGROUND)
    cr.set_source_rgb(bg.red, bg.green, bg.blue)
    cr.paint()
    cr.set_source_surface(shot, PAD, PAD)
    cr.paint()
    x = 2 * PAD
    for s in below:
        cr.set_source_surface(s, x, shot.get_height() + 2 * PAD)
        cr.paint()
        x += s.get_width() + PAD
    page.write_to_png(out)


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--render":
        mode, out = sys.argv[2], sys.argv[3]
        render_gtk3(out) if mode == "gtk3" else render_gtk4(mode == "adw", out)
    elif len(sys.argv) in (5, 6) and sys.argv[1] in ("gtk3", "gtk4", "adw"):
        launch(*sys.argv[1:])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
