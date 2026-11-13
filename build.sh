#!/usr/bin/env bash
# Construit "Lagoon" : un thème KDE Plasma 6 dans la palette Catppuccin Mocha (accent
# Teal), avec des rayons d'angle communs à Plasma, Qt et GTK.
#
# Installe dans ~/.local/share, ou dans $DEST si défini (ex. : DEST=dist/share ./build.sh).
# Nécessite librsvg et python3, sans module à installer. Avec un compilateur C et les en-têtes
# de GTK 3, les boutons de fenêtre des applis GTK 3 s'allument ensemble ; sans, un par un ; avec
# wayland-scanner en plus, KWin floute derrière leurs fenêtres, comme derrière celles de Qt. Avec
# un compilateur C++ et ceux de Qt 6, le panneau Emplacements de KIO garde un texte lisible.
set -euo pipefail

HERE=$(dirname "$(realpath "$0")")
SRC_CATPPUCCIN=$HERE/vendor/catppuccin-kde

DATA=${DEST:-$HOME/.local/share}
LNF=$DATA/plasma/look-and-feel/Lagoon
PLASMA=$DATA/plasma/desktoptheme/Lagoon
COLORS=$DATA/color-schemes/Lagoon.colors

# --- Thème Plasma (plasma/desktoptheme/Lagoon : panneaux, popups et widgets) ---
rm -rf "$PLASMA"
mkdir -p "$(dirname "$PLASMA")"
cp -r "$HERE/plasma/desktoptheme/Lagoon" "$PLASMA"

# Panneaux, popups et infobulles translucides et floutés quand KWin floute (translucent/),
# opaques sinon ; solid/ pour les panneaux réglés opaques et leurs popups
python3 -I "$HERE/plasma/desktoptheme/build-translucent.py" "$HERE/plasma/desktoptheme/Lagoon" "$PLASMA"

# --- Thème GTK : le style de libadwaita (adw-gtk3) aux couleurs de Catppuccin Mocha, accent teal ;
# les applis libadwaita lisent la même palette (gtk-4.0/lagoon.css, voir install.sh) ---
python3 -I "$HERE/gtk/build-gtk.py" "$HERE/vendor/adw-gtk3" "$DATA/themes" Lagoon
# --- Module GTK 3 (optionnel) : les boutons de fenêtre s'allument ensemble, voir gtk/lagoonbuttons.c ;
# avec wayland-scanner, il demande aussi à KWin de flouter derrière les fenêtres (gtk/lagoonblur.c) ---
if command -v cc >/dev/null && pkg-config --exists gtk+-3.0 2>/dev/null; then
  gtk_build=$(mktemp -d)
  blur=()
  if command -v wayland-scanner >/dev/null && pkg-config --exists wayland-client 2>/dev/null; then
    blur=(-DLAGOON_BLUR -I"$gtk_build" "$HERE/gtk/lagoonblur.c")
    for xml in plasma-wayland-protocols/blur wayland-protocols/ext-background-effect-v1; do
      p=$(basename "$xml")
      wayland-scanner client-header "$HERE/vendor/$xml.xml" "$gtk_build/$p-client-protocol.h"
      wayland-scanner private-code "$HERE/vendor/$xml.xml" "$gtk_build/$p-protocol.c"
      blur+=("$gtk_build/$p-protocol.c")
    done
    # shellcheck disable=SC2207  # les options de pkg-config sont à découper
    blur+=(-lm
          $(pkg-config --cflags --libs wayland-client))
  else
    echo "Pas de wayland-scanner : les applis GTK 3 ne seront pas floutées" >&2
  fi
  # shellcheck disable=SC2046  # les options de pkg-config sont à découper
  cc -shared -fPIC -O2 -Wall -o "$DATA/themes/Lagoon/gtk-3.0/liblagoonbuttons.so" \
    "$HERE/gtk/lagoonbuttons.c" "${blur[@]}" $(pkg-config --cflags --libs gtk+-3.0)
  rm -rf "$gtk_build"
else
  echo "Pas de compilateur C ou d'en-têtes GTK 3 : les boutons des applis GTK 3 réagiront un par un" >&2
fi
# --- Plugin Qt 6 (optionnel) : le texte de la sélection du panneau Emplacements, voir qt/ ---
if command -v c++ >/dev/null && pkg-config --exists Qt6Widgets 2>/dev/null; then
  qt_build=$(mktemp -d)
  # shellcheck disable=SC2046  # les options de pkg-config sont à découper
  "$(pkg-config --variable=libexecdir Qt6Core)/moc" $(pkg-config --cflags-only-I Qt6Widgets Qt6Gui Qt6Core) \
    -I"$HERE/qt" "$HERE/qt/lagoonplaces.cpp" -o "$qt_build/lagoonplaces.moc"
  mkdir -p "$DATA/themes/Lagoon/qt6/generic"
  # shellcheck disable=SC2046
  c++ -std=c++17 -shared -fPIC -O2 -Wall -I"$qt_build" -o "$DATA/themes/Lagoon/qt6/generic/liblagoonplaces.so" \
    "$HERE/qt/lagoonplaces.cpp" $(pkg-config --cflags --libs Qt6Widgets Qt6Gui Qt6Core)
  rm -rf "$qt_build"
else
  echo "Pas de compilateur C++ ou d'en-têtes Qt 6 : le panneau Emplacements gardera un texte clair" >&2
fi
# --- Style d'applications Kvantum (optionnel) : KvLibadwaita Dark (le style des applis GNOME)
# aux couleurs et rayons du thème ; menus et infobulles translucides et floutés. Kvantum
# cherche aussi ses thèmes dans le dossier des thèmes GTK.
python3 -I "$HERE/kvantum/build-kvantum.py" "$HERE/vendor/kvlibadwaita" \
  "$DATA/themes/Lagoon/Kvantum" Lagoon


# --- Curseurs Teal : Catppuccin Mocha Teal (v2.0.0, GPL-2.0), retouchés par icons/build-cursors.py :
# contour plus épais, dégradé, flèche arrondie ---
rm -rf "$DATA/icons/Teal-cursors"
mkdir -p "$DATA/icons"
cp -r "$HERE/icons/Teal-cursors" "$DATA/icons/Teal-cursors"
python3 -I "$HERE/icons/build-cursors.py" \
  "$HERE/vendor/catppuccin-cursors/catppuccin-mocha-teal-cursors.zip" "$DATA/icons/Teal-cursors"

# --- Icône du lanceur : le logo CachyOS sans tuile, dans hicolor pour rester là avec --no-icons ---
mkdir -p "$DATA/icons/hicolor/scalable/apps"
python3 -I "$HERE/wallpapers/make-wallpaper.py" "$HERE/wallpapers/cachyos-logo.svg" \
  "$DATA/icons/hicolor/scalable/apps/lagoon-launcher.svg" --logo-only

# --- Fond d'écran : vagues et logo CachyOS aux couleurs Mocha (paquet de fond d'écran Plasma) ---
# mêmes tailles pour le fond d'écran et le fond du splash (le splash choisit comme Plasma)
SIZES="3840x2160 2560x1600 2560x1440 1920x1200 1920x1080 3440x1440 1366x768"
WP=$DATA/wallpapers/Lagoon
rm -rf "$WP"
mkdir -p "$WP/contents/images"
cp "$HERE/wallpapers/Lagoon/metadata.json" "$WP/"
for size in $SIZES; do
  python3 -I "$HERE/wallpapers/make-wallpaper.py" "$HERE/wallpapers/cachyos-logo.svg" \
    "$WP/contents/images/$size.png" "${size%x*}" "${size#*x}"
done
python3 -I "$HERE/wallpapers/make-wallpaper.py" "$HERE/wallpapers/cachyos-logo.svg" \
  "$WP/contents/screenshot.png" 400 250

# --- Le même sans le logo, « Waves » : pour l'écran de verrouillage, qui le floute derrière
# l'avatar et le mot de passe ---
WAVES=$DATA/wallpapers/Lagoon-Waves
rm -rf "$WAVES"
mkdir -p "$WAVES/contents/images"
cp "$HERE/wallpapers/Lagoon-Waves/metadata.json" "$WAVES/"
for size in $SIZES; do
  python3 -I "$HERE/wallpapers/make-wallpaper.py" "$HERE/wallpapers/cachyos-logo.svg" \
    "$WAVES/contents/images/$size.png" "${size%x*}" "${size#*x}" --no-logo
done
python3 -I "$HERE/wallpapers/make-wallpaper.py" "$HERE/wallpapers/cachyos-logo.svg" \
  "$WAVES/contents/screenshot.png" 400 250 --no-logo

# --- Konsole : le jeu de couleurs Mocha du terminal et un profil qui le prend (install.sh n'en
# fait le profil par défaut que si l'utilisateur n'en a pas choisi un) ---
mkdir -p "$DATA/konsole"
cp "$HERE/konsole/Lagoon.colorscheme" "$HERE/konsole/Lagoon.profile" "$DATA/konsole/"

# --- Jeu de couleurs ---
mkdir -p "$(dirname "$COLORS")"
sed -e 's/^Name=.*/Name=Lagoon/' "$SRC_CATPPUCCIN/CatppuccinMochaTeal.colors" > "$COLORS"

# --- Décoration de fenêtres : Catppuccin Mocha Classic (Aurorae, MIT) ---
mkdir -p "$DATA/aurorae/themes"
rm -rf "$DATA/aurorae/themes/CatppuccinMocha-Classic"
cp -r "$SRC_CATPPUCCIN/CatppuccinMocha-Classic" "$DATA/aurorae/themes/"
# sa licence (MIT, celle du jeu de couleurs aussi) voyage avec lui
cp "$SRC_CATPPUCCIN/LICENSE" "$DATA/aurorae/themes/CatppuccinMocha-Classic/"

# --- Thème global ---
# plasma/look-and-feel/Lagoon : ses métadonnées, ses réglages (defaults), le splash et les aperçus ;
# s'y ajoutent ici les images du splash et la disposition
rm -rf "$LNF"
mkdir -p "$(dirname "$LNF")"
cp -r "$HERE/plasma/look-and-feel/Lagoon" "$LNF"
c=$LNF/contents
# pas d'écran de verrouillage, de déconnexion ni d'OSD propres : Plasma utilise les siens,
# maintenus et qui suivent le jeu de couleurs
mkdir -p "$c/layouts"
# splash (d'après celui de MacTahoe, GPL-3.0) : le fond d'écran, avec le logo CachyOS
# à la même place ; ses trois bulles, animées en QML, s'échappent du C pendant le chargement
mkdir -p "$c/splash/images"
# fond du splash : le fond d'écran sans logo, dans les mêmes tailles, pour que les vagues
# coïncident aussi avec le bureau quel que soit le format de l'écran
for size in $SIZES; do
  python3 -I "$HERE/wallpapers/make-wallpaper.py" "$HERE/wallpapers/cachyos-logo.svg" \
    "$c/splash/images/background-$size.png" "${size%x*}" "${size#*x}" --no-logo
done
sizes_js=$(printf '"%s", ' $SIZES)
sed -i "s|@BACKGROUND_SIZES@|[${sizes_js%, }]|" "$c/splash/Splash.qml"
python3 -I "$HERE/wallpapers/make-wallpaper.py" "$HERE/wallpapers/cachyos-logo.svg" \
  "$c/splash/images/logo-c.svg" --logo-only --no-bubbles

# disposition : barre du haut et dock flottant, widgets de Plasma uniquement
# the global theme's layout: the top bar and the dock, from their "Add Panel" templates
{
  echo "// Lagoon layout: the top bar and the floating dock (plasma/layout-templates/, joined by build.sh)."
  for t in topbar dock; do
    echo "(function () {"
    cat "$HERE/plasma/layout-templates/com.github.elomkdn.lagoon.$t/contents/layout.js"
    echo "})();"
  done
} > "$c/layouts/org.kde.plasma.desktop-layout.js"
# les mêmes, en modèles de panneaux (« Ajouter un panneau »), sans remplacer la disposition
mkdir -p "$DATA/plasma/layout-templates"
for t in "$HERE"/plasma/layout-templates/*/; do
  rm -rf "$DATA/plasma/layout-templates/$(basename "$t")"
  cp -r "$t" "$DATA/plasma/layout-templates/"
done

# Teal Pill, the top bar's music island (vendor/teal-pill, from github.com/elomkdn/teal-pill),
# with its French catalog
PILL=$DATA/plasma/plasmoids/com.github.elomkdn.tealpill
rm -rf "$PILL"
mkdir -p "$(dirname "$PILL")"
cp -r "$HERE/vendor/teal-pill/package" "$PILL"
if command -v msgfmt >/dev/null; then
  mkdir -p "$PILL/contents/locale/fr/LC_MESSAGES"
  msgfmt -o "$PILL/contents/locale/fr/LC_MESSAGES/plasma_applet_com.github.elomkdn.tealpill.mo" \
    "$HERE/vendor/teal-pill/po/fr.po"
fi

# Lagoon Title: the active app's name, before the global menu
TITLE=$DATA/plasma/plasmoids/com.github.elomkdn.lagoon.title
rm -rf "$TITLE"
cp -r "$HERE/plasma/plasmoids/com.github.elomkdn.lagoon.title" "$TITLE"


echo "OK : $LNF"
