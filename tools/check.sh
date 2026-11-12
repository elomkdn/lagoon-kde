#!/usr/bin/env bash
# Ce qui doit tenir avant de publier Lagoon : les scripts se lisent, le thème se construit, ses
# fichiers sont valides, et l'installeur puis le désinstalleur font ce que le README promet,
# dans un dossier personnel jetable où attendent déjà des réglages d'un utilisateur (ses icônes,
# ses curseurs, ses configurations Kvantum et Klassy, un accès Flatpak, un profil Firefox).
# Rien n'est appliqué à la session en cours.
#
# usage : tools/check.sh
# Nécessite ce que demande la construction (python3, librsvg) et kconfig (kwriteconfig6).
set -uo pipefail

HERE=$(realpath "$(dirname "$(realpath "$0")")/..")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
failed=0
ok() { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; failed=1; }
expect() { # description, commande… : la commande doit réussir
  local what=$1; shift
  if "$@" >/dev/null 2>&1; then ok "$what"; else bad "$what"; fi
}

cd "$HERE"
echo "Scripts"
for f in *.sh tools/*.sh; do bash -n "$f" || bad "$f"; done
expect "ils se lisent" python3 -I -m py_compile gtk/*.py kvantum/*.py plasma/desktoptheme/*.py wallpapers/*.py tools/*.py

echo "Construction"
if DEST="$WORK/rel/share" ./build.sh > "$WORK/build.log" 2>&1; then ok "le thème se construit"; else cat "$WORK/build.log" >&2; bad "la construction"; fi
python3 -I - "$WORK/rel/share" <<'EOF' && ok "JSON, SVG et QML valides" || bad "un fichier construit n'est pas valide"
import gzip, json, sys
from pathlib import Path
from xml.dom import minidom
bad = []
for f in Path(sys.argv[1]).rglob("*"):
    try:
        if f.suffix == ".json":
            json.loads(f.read_text())
        elif f.suffix == ".svg" and f.is_file():
            minidom.parse(str(f))
        elif f.suffix == ".svgz":
            minidom.parseString(gzip.decompress(f.read_bytes()))
        elif f.suffix == ".qml" and "@BACKGROUND_SIZES@" in f.read_text():
            bad.append(f"{f}: une marque n'a pas été remplacée")
    except Exception as error:
        bad.append(f"{f}: {error}")
if bad:
    sys.exit("\n".join(bad))
EOF

echo "Installation, dans un dossier jetable"
if ! command -v kwriteconfig6 >/dev/null; then
  bad "kwriteconfig6 manque (paquet kconfig)"
  exit 1
fi
cp install.sh uninstall.sh "$WORK/rel/"
cp -r extras "$WORK/rel/"
H=$WORK/home; C=$H/.config; D=$H/.local/share
mkdir -p "$WORK/bin" "$C/Kvantum" "$C/klassy" "$C/xsettingsd" "$D/icons/catppuccin-mocha-teal-cursors" \
         "$D/flatpak/overrides" "$H/.mozilla/firefox/abc.default"
# gsettings écrirait dans le vrai dconf, pkill relancerait son service : des faux
cat > "$WORK/bin/gsettings" <<'EOF'
#!/bin/sh
f="$HOME/.gsettings-$3"
case $1 in set) printf "'%s'\n" "$4" > "$f" ;; get) cat "$f" 2>/dev/null || echo "'Adwaita'" ;; esac
EOF
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/pkill"
chmod +x "$WORK/bin/gsettings" "$WORK/bin/pkill"
run() { env -i HOME="$H" XDG_DATA_HOME="$D" XDG_CONFIG_HOME="$C" XDG_CACHE_HOME="$H/.cache" XDG_CONFIG_DIRS=/etc/xdg \
            DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent PATH="$WORK/bin:/usr/bin:/bin" "$@"; }
read_key() { run kreadconfig6 --file "$1" --group "$2" --key "$3" 2>/dev/null; }

# ce que l'utilisateur avait avant Lagoon
run kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark
printf '[General]\ntheme=KvArc\n' > "$C/Kvantum/kvantum.kvconfig"
printf '[Windeco]\nMine=1\n' > "$C/klassy/klassyrc"
printf 'Net/ThemeName "Breeze"\nNet/IconThemeName "x"\n' > "$C/xsettingsd/xsettingsd.conf"
printf '[Context]\nfilesystems=~/Games;xdg-data/themes:ro;\n' > "$D/flatpak/overrides/global"
printf '[Profile0]\nPath=abc.default\nIsRelative=1\n' > "$H/.mozilla/firefox/profiles.ini"

# depuis le dossier parent, où « Lagoon » pourrait être pris pour le thème (voir install.sh)
if (cd "$WORK" && run ./rel/install.sh --no-apply --no-icons --firefox) > "$WORK/install.log" 2>&1; then
  ok "l'installeur va au bout"
else
  cat "$WORK/install.log" >&2; bad "l'installeur"
fi
for part in plasma/look-and-feel/Lagoon/metadata.json plasma/desktoptheme/Lagoon/metadata.json color-schemes/Lagoon.colors \
            themes/Lagoon/gtk-4.0/lagoon.css themes/Lagoon/gtk-3.0/liblagoonbuttons.so themes/Lagoon/qt6/generic/liblagoonplaces.so themes/Lagoon/Kvantum/Lagoon.kvconfig wallpapers/Lagoon/metadata.json \
            plasma/plasmoids/com.github.elomkdn.tealpill/metadata.json konsole/Lagoon.colorscheme; do
  [ -e "$D/$part" ] || bad "il manque $part"
done
expect "sans --apply, les icônes de l'utilisateur restent" test "$(read_key kdeglobals Icons Theme)" = Papirus-Dark
expect "sans --apply, le profil du terminal reste" test -z "$(read_key konsolerc "Desktop Entry" DefaultProfile)"
expect "ce qui était là avant est noté" grep -qx cursors "$C/lagoon/kept"
expect "le thème Kvantum est choisi, l'ancien gardé" test "$(read_key "$C/Kvantum/kvantum.kvconfig" General theme)$(read_key "$C/Kvantum/kvantum.kvconfig.bak" General theme)" = LagoonKvArc
expect "le thème GTK est choisi" grep -qx "gtk-theme-name=Lagoon" "$C/gtk-3.0/settings.ini"
expect "les applis libadwaita lisent la palette" grep -q "/themes/Lagoon/gtk-4.0/lagoon.css" "$C/gtk-4.0/gtk.css"
expect "les applis GTK 3 chargent le module des boutons" grep -q "themes/Lagoon/gtk-3.0/liblagoonbuttons.so" "$C/plasma-workspace/env/lagoon-gtk3.sh"
expect "les applis Qt chargent le plugin du panneau Emplacements" grep -q "themes/Lagoon/qt6" "$C/plasma-workspace/env/lagoon-qt.sh"
expect "Firefox lit les pastilles" grep -q "// Lagoon" "$H/.mozilla/firefox/abc.default/user.js"
expect "la configuration Klassy de l'utilisateur reste" grep -qx "Mine=1" "$C/klassy/klassyrc"
if command -v flatpak >/dev/null; then
  expect "les applis Flatpak voient le thème" grep -q "xdg-config/gtk-4.0:ro" "$D/flatpak/overrides/global"
fi

echo "Désinstallation"
if (cd "$WORK" && run ./rel/uninstall.sh) > "$WORK/uninstall.log" 2>&1; then ok "le désinstalleur va au bout"; else cat "$WORK/uninstall.log" >&2; bad "le désinstalleur"; fi
for part in plasma/look-and-feel/Lagoon plasma/desktoptheme/Lagoon themes/Lagoon wallpapers/Lagoon konsole/Lagoon.colorscheme \
            plasma/plasmoids/com.github.elomkdn.tealpill aurorae/themes/CatppuccinMocha-Classic; do
  [ ! -e "$D/$part" ] || bad "il reste $part"
done
expect "les curseurs d'avant restent" test -d "$D/icons/catppuccin-mocha-teal-cursors"
# Flatpak réordonne ses accès : ceux d'avant sont là, celui de l'installeur n'y est plus
expect "l'accès Flatpak d'avant reste" sh -c "grep -q '~/Games' '$D/flatpak/overrides/global' && grep -q 'xdg-data/themes:ro' '$D/flatpak/overrides/global'"
expect "celui de l'installeur est retiré" sh -c "! grep -q 'xdg-config/gtk-4.0' '$D/flatpak/overrides/global'"
expect "la configuration Kvantum d'avant revient" test "$(read_key "$C/Kvantum/kvantum.kvconfig" General theme)" = KvArc
expect "sa copie de secours est retirée" test ! -e "$C/Kvantum/kvantum.kvconfig.bak"
expect "la configuration Klassy de l'utilisateur reste" grep -qx "Mine=1" "$C/klassy/klassyrc"
expect "Firefox est rendu comme avant" test ! -e "$H/.mozilla/firefox/abc.default/chrome" -a ! -e "$H/.mozilla/firefox/abc.default/user.js"
expect "xsettingsd revient à Breeze" grep -qx 'Net/ThemeName "Breeze"' "$C/xsettingsd/xsettingsd.conf"
expect "le thème GTK revient à Breeze" grep -qx "gtk-theme-name=Breeze" "$C/gtk-3.0/settings.ini"
expect "le module GTK 3 n'est plus chargé" test ! -e "$C/plasma-workspace/env/lagoon-gtk3.sh"
expect "le plugin Qt n'est plus chargé" test ! -e "$C/plasma-workspace/env/lagoon-qt.sh"
expect "la ligne de libadwaita est retirée" sh -c "! grep -q Lagoon '$C/gtk-4.0/gtk.css'"
expect "plus de trace de l'installeur" test ! -e "$C/lagoon"

if [ "$failed" -eq 0 ]; then echo "Tout est bon."; else echo "Quelque chose ne va pas." >&2; exit 1; fi
