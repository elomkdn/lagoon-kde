#!/usr/bin/env bash
# Construit "Lagoon" : un thème KDE Plasma 6 dans la palette Catppuccin Mocha (accent
# Teal), avec des rayons d'angle communs à Plasma, Qt et GTK.
#
# Installe dans ~/.local/share, ou dans $DEST si défini (ex. : DEST=dist/share ./build.sh).
# Nécessite librsvg et python3.
set -euo pipefail

HERE=$(dirname "$(realpath "$0")")
SRC_CATPPUCCIN=$HERE/vendor/catppuccin-kde

DATA=${DEST:-$HOME/.local/share}
LNF=$DATA/plasma/look-and-feel/Lagoon
PLASMA=$DATA/plasma/desktoptheme/Lagoon
COLORS=$DATA/color-schemes/Lagoon.colors

# --- Thème Plasma (plasma-theme/ : panneaux, popups et widgets) ---
rm -rf "$PLASMA"
mkdir -p "$(dirname "$PLASMA")"
cp -r "$HERE/plasma-theme" "$PLASMA"
cat > "$PLASMA/metadata.json" <<EOF
{
    "KPackageStructure": "Plasma/Theme",
    "KPlugin": {
        "Authors": [ { "Name": "Elom" } ],
        "Category": "Plasma Theme",
        "Description": "Plasma theme in Catppuccin Mocha with the Teal accent",
        "EnabledByDefault": true,
        "Id": "Lagoon",
        "License": "GPL-3.0-or-later",
        "Name": "Lagoon"
    },
    "X-Plasma-API-Minimum-Version": "6.0"
}
EOF

# Pas de flou ni de contraste derrière panneaux et popups : la région de flou de KWin
# est alignée sur les pixels et dessine un liseré « scié » sur les coins arrondis.
cat > "$PLASMA/plasmarc" <<'EOF'
[Wallpaper]
defaultWallpaperTheme=Lagoon
defaultFileSuffix=.png
defaultWidth=1920
defaultHeight=1080

[BlurBehindEffect]
enabled=false

[ContrastEffect]
enabled=false

[AdaptiveTransparency]
enabled=false
EOF

# --- Thème GTK : le style de libadwaita (adw-gtk3) aux couleurs de Catppuccin Mocha, accent teal ;
# les applis libadwaita lisent la même palette (gtk-4.0/lagoon.css, voir install.sh) ---
python3 -I "$HERE/build-gtk.py" "$HERE/vendor/adw-gtk3" "$DATA/themes" Lagoon
# --- Style d'applications Kvantum (optionnel) : KvLibadwaita Dark (le style des applis GNOME)
# aux couleurs et rayons du thème, opaque. Kvantum cherche aussi ses thèmes dans le dossier
# des thèmes GTK.
python3 -I "$HERE/build-kvantum.py" "$HERE/vendor/kvlibadwaita" \
  "$DATA/themes/Lagoon/Kvantum" Lagoon


# --- Curseurs : Catppuccin Mocha Teal (v2.0.0, GPL-2.0), tels quels ---
rm -rf "$DATA/icons/catppuccin-mocha-teal-cursors"
python3 -I -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' \
  "$HERE/vendor/catppuccin-cursors/catppuccin-mocha-teal-cursors.zip" "$DATA/icons"

# --- Icône du lanceur : le logo CachyOS sans tuile, dans hicolor pour rester là avec --no-icons ---
mkdir -p "$DATA/icons/hicolor/scalable/apps"
python3 -I "$HERE/wallpaper/make-wallpaper.py" "$HERE/wallpaper/cachyos-logo.svg" \
  "$DATA/icons/hicolor/scalable/apps/lagoon-launcher.svg" --logo-only

# --- Fond d'écran : vagues et logo CachyOS aux couleurs Mocha (paquet de fond d'écran Plasma) ---
# mêmes tailles pour le fond d'écran et le fond du splash (le splash choisit comme Plasma)
SIZES="3840x2160 2560x1600 2560x1440 1920x1200 1920x1080 3440x1440 1366x768"
WP=$DATA/wallpapers/Lagoon
rm -rf "$WP"
mkdir -p "$WP/contents/images"
for size in $SIZES; do
  python3 -I "$HERE/wallpaper/make-wallpaper.py" "$HERE/wallpaper/cachyos-logo.svg" \
    "$WP/contents/images/$size.png" "${size%x*}" "${size#*x}"
done
python3 -I "$HERE/wallpaper/make-wallpaper.py" "$HERE/wallpaper/cachyos-logo.svg" \
  "$WP/contents/screenshot.png" 400 250
cat > "$WP/metadata.json" <<EOF
{
    "KPlugin": {
        "Authors": [ { "Name": "Elom" } ],
        "Id": "Lagoon",
        "License": "GPL-1.0-only",
        "Name": "Lagoon"
    }
}
EOF

# --- Le même sans le logo, « Waves » : pour l'écran de verrouillage, qui le floute derrière
# l'avatar et le mot de passe ---
WAVES=$DATA/wallpapers/Lagoon-Waves
rm -rf "$WAVES"
mkdir -p "$WAVES/contents/images"
for size in $SIZES; do
  python3 -I "$HERE/wallpaper/make-wallpaper.py" "$HERE/wallpaper/cachyos-logo.svg" \
    "$WAVES/contents/images/$size.png" "${size%x*}" "${size#*x}" --no-logo
done
python3 -I "$HERE/wallpaper/make-wallpaper.py" "$HERE/wallpaper/cachyos-logo.svg" \
  "$WAVES/contents/screenshot.png" 400 250 --no-logo
cat > "$WAVES/metadata.json" <<EOF
{
    "KPlugin": {
        "Authors": [ { "Name": "Elom" } ],
        "Id": "Lagoon-Waves",
        "License": "GPL-3.0-or-later",
        "Name": "Lagoon Waves"
    }
}
EOF

# --- Second fond d'écran, « Glow » : un arc de lumière teal à travers du verre cannelé ---
GLOW=$DATA/wallpapers/Lagoon-Glow
rm -rf "$GLOW"
mkdir -p "$GLOW/contents/images"
for size in $SIZES; do
  python3 -I "$HERE/wallpaper/make-glow.py" "$GLOW/contents/images/$size.png" "${size%x*}" "${size#*x}"
done
python3 -I "$HERE/wallpaper/make-glow.py" "$GLOW/contents/screenshot.png" 400 250
cat > "$GLOW/metadata.json" <<EOF
{
    "KPlugin": {
        "Authors": [ { "Name": "Elom" } ],
        "Id": "Lagoon-Glow",
        "License": "GPL-3.0-or-later",
        "Name": "Lagoon Glow"
    }
}
EOF

# --- Jeu de couleurs ---
mkdir -p "$(dirname "$COLORS")"
sed -e 's/^Name=.*/Name=Lagoon/' "$SRC_CATPPUCCIN/CatppuccinMochaTeal.colors" > "$COLORS"

# --- Décoration de fenêtres : Catppuccin Mocha Classic (Aurorae, MIT) ---
mkdir -p "$DATA/aurorae/themes"
rm -rf "$DATA/aurorae/themes/CatppuccinMocha-Classic"
cp -r "$SRC_CATPPUCCIN/CatppuccinMocha-Classic" "$DATA/aurorae/themes/"

# --- Thème global ---
rm -rf "$LNF"
mkdir -p "$(dirname "$LNF")"
c=$LNF/contents
# pas d'écran de verrouillage, de déconnexion ni d'OSD propres : Plasma utilise les siens,
# maintenus et qui suivent le jeu de couleurs
mkdir -p "$c/layouts"
# splash (d'après celui de MacTahoe, GPL-3.0) : le fond d'écran, avec le logo CachyOS
# à la même place ; ses trois bulles, animées en QML, s'échappent du C pendant le chargement
rm -rf "$c/splash"
cp -r "$HERE/splash" "$c/splash"
mkdir -p "$c/splash/images"
# fond du splash : le fond d'écran sans logo, dans les mêmes tailles, pour que les vagues
# coïncident aussi avec le bureau quel que soit le format de l'écran
for size in $SIZES; do
  python3 -I "$HERE/wallpaper/make-wallpaper.py" "$HERE/wallpaper/cachyos-logo.svg" \
    "$c/splash/images/background-$size.png" "${size%x*}" "${size#*x}" --no-logo
done
sizes_js=$(printf '"%s", ' $SIZES)
sed -i "s|@BACKGROUND_SIZES@|[${sizes_js%, }]|" "$c/splash/Splash.qml"
python3 -I "$HERE/wallpaper/make-wallpaper.py" "$HERE/wallpaper/cachyos-logo.svg" \
  "$c/splash/images/logo-c.svg" --logo-only --no-bubbles

# aperçus (Configuration du système) : capture du thème et instant de l'animation du splash
rm -rf "$c/previews"
cp -r "$HERE/previews" "$c/previews"

# disposition : barre du haut et dock flottant, widgets de Plasma uniquement
# the global theme's layout: the top bar and the dock, from their "Add Panel" templates
{
  echo "// Lagoon layout: the top bar and the floating dock (layout-templates/, joined by build.sh)."
  for t in topbar dock; do
    echo "(function () {"
    cat "$HERE/layout-templates/com.github.elomkdn.lagoon.$t/contents/layout.js"
    echo "})();"
  done
} > "$c/layouts/org.kde.plasma.desktop-layout.js"
# les mêmes, en modèles de panneaux (« Ajouter un panneau »), sans remplacer la disposition
mkdir -p "$DATA/plasma/layout-templates"
for t in "$HERE"/layout-templates/*/; do
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
cat > "$LNF/metadata.json" <<EOF
{
    "KPackageStructure": "Plasma/LookAndFeel",
    "KPlugin": {
        "Authors": [ { "Name": "Elom" } ],
        "Category": "Global Themes",
        "Description": "Catppuccin Mocha with the Teal accent, for CachyOS",
        "EnabledByDefault": true,
        "Id": "Lagoon",
        "License": "GPL-3.0-or-later",
        "Name": "Lagoon"
    },
    "X-KPackage-Dependencies": [ ]
}
EOF

cat > "$c/defaults" <<'EOF'
[kcminputrc][Mouse]
cursorTheme=catppuccin-mocha-teal-cursors

[kdeglobals][General]
ColorScheme=Lagoon

[kdeglobals][Icons]
Theme=Teal

[kdeglobals][KDE]
widgetStyle=kvantum

[Kvantum/kvantum.kvconfig][General]
theme=Lagoon

[kwinrc][WindowSwitcher]
LayoutName=big_icons

[kwinrc][DesktopSwitcher]
LayoutName=big_icons

[kwinrc][org.kde.kdecoration2]
library=org.kde.kwin.aurorae.v2
theme=__aurorae__svg__CatppuccinMocha-Classic

[plasmarc][Theme]
name=Lagoon

[Wallpaper]
Image=Lagoon
EOF

echo "OK : $LNF"
