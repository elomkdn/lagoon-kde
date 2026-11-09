#!/usr/bin/env bash
# Removes Lagoon for the current user: the global theme, Plasma theme, colors, GTK and Kvantum
# themes, wallpapers, panel templates, cursors, window decoration, Teal Pill and the Teal
# icons, and the settings install.sh made (libadwaita's line, Kvantum's choice, Firefox's
# dots). If Lagoon is in use, Plasma goes back to Breeze Dark first; your panels stay.
#
# usage: ./uninstall.sh
set -euo pipefail

DATA=${XDG_DATA_HOME:-$HOME/.local/share}
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
THEME=Lagoon

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
interactive=false
[ -t 1 ] && [ -t 0 ] && interactive=true

step() { # message, command…
  local message=$1; shift
  if ! $interactive; then
    echo "$message…"
    "$@"
    return
  fi
  "$@" > "$WORK/step.log" 2>&1 &
  local pid=$! frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0 status=0
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r  \033[36m%s\033[0m %s' "${frames:i++%${#frames}:1}" "$message"
    sleep 0.08
  done
  wait "$pid" || status=$?
  if [ "$status" -eq 0 ]; then
    printf '\r  \033[32m✓\033[0m %s\n' "$message"
  else
    printf '\r  \033[31m✗\033[0m %s\n' "$message"
    cat "$WORK/step.log" >&2
    exit "$status"
  fi
}

note() { # a line under the steps
  if $interactive; then printf '    %s\n' "$*"; else echo "$*"; fi
}


$interactive && printf '\n  \033[1mLagoon\033[0m, uninstalling\n\n'

back_to_breeze() {
  # Lagoon's wallpapers are about to go
  if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && [ -d /usr/share/wallpapers/Next ] &&
      grep -q '^Image=.*wallpapers/Lagoon' "$CONFIG/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null; then
    plasma-apply-wallpaperimage /usr/share/wallpapers/Next >/dev/null 2>&1 || true
  fi
  # Plasma's own look, keeping the panels; without a session, the settings it would write
  if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && command -v plasma-apply-lookandfeel >/dev/null; then
    plasma-apply-lookandfeel -a org.kde.breezedark.desktop
  else
    kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
    kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark
    kwriteconfig6 --file plasmarc --group Theme --key name default
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme breeze_cursors
    kwriteconfig6 --file ksplashrc --group KSplash --key Theme org.kde.breeze.desktop
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Breeze
  fi
  local f
  for f in "$CONFIG/gtk-3.0/settings.ini" "$CONFIG/gtk-4.0/settings.ini"; do
    [ -f "$f" ] && sed -i "s/^gtk-theme-name=$THEME$/gtk-theme-name=Breeze/" "$f"
  done
  if command -v gsettings >/dev/null && [ "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)" = "'$THEME'" ]; then
    gsettings set org.gnome.desktop.interface gtk-theme Breeze || true
  fi
}
remove_lagoon() {
  local part ini path dir
  for part in plasma/look-and-feel/Lagoon plasma/desktoptheme/Lagoon color-schemes/Lagoon.colors \
      themes/$THEME themes/$THEME-KIO wallpapers/Lagoon wallpapers/Lagoon-Glow wallpapers/Lagoon-Waves \
      plasma/layout-templates/com.github.elomkdn.lagoon.dock \
      plasma/layout-templates/com.github.elomkdn.lagoon.topbar \
      plasma/plasmoids/com.github.elomkdn.tealpill icons/catppuccin-mocha-teal-cursors \
      aurorae/themes/CatppuccinMocha-Classic icons/Teal icons/Teal-Papirus icons/Teal-Settings \
      icons/hicolor/scalable/apps/lagoon-launcher.svg; do
    rm -rf "${DATA:?}/$part"
  done
  [ -L "$HOME/.icons/catppuccin-mocha-teal-cursors" ] && rm -f "$HOME/.icons/catppuccin-mocha-teal-cursors"
  # System Settings' own icon theme, Teal-Settings
  kwriteconfig6 --file systemsettingsrc --group Icons --key Theme --delete 2>/dev/null || true
  # the local copies of .desktop files Teal made to name its icons
  # (grep fails when there are none, which must not stop the rest of the cleaning)
  { grep -l '^X-Teal-Icon=true' "$DATA"/applications/*.desktop 2>/dev/null || true; } | xargs -r rm -f
  # the lock screen's wallpaper, if it is still ours
  local lock=(--file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General)
  case $(kreadconfig6 "${lock[@]}" --key Image 2>/dev/null) in
    *wallpapers/Lagoon-Waves*)
      kwriteconfig6 "${lock[@]}" --key Image --delete
      kwriteconfig6 "${lock[@]}" --key PreviewImage --delete ;;
  esac
  # the libadwaita line, Kvantum's choice, Firefox's dots
  [ -f "$CONFIG/gtk-4.0/gtk.css" ] && sed -i "\|/themes/$THEME/gtk-4.0/|d" "$CONFIG/gtk-4.0/gtk.css"
  local kv=$CONFIG/Kvantum/kvantum.kvconfig
  if [ "$(kreadconfig6 --file "$kv" --group General --key theme 2>/dev/null)" = "$THEME" ]; then
    kwriteconfig6 --file "$kv" --group General --key theme --delete
  fi
  kwriteconfig6 --file "$kv" --group Applications --key "$THEME-KIO" --delete 2>/dev/null || true
  for ini in "$CONFIG/mozilla/firefox/profiles.ini" "$HOME/.mozilla/firefox/profiles.ini"; do
    [ -f "$ini" ] || continue
    while IFS= read -r path; do
      case $path in /*) dir=$path ;; *) dir=$(dirname "$ini")/$path ;; esac
      [ -f "$dir/chrome/lagoon.css" ] || continue
      rm -f "$dir/chrome/lagoon.css"
      sed -i '/@import url("lagoon.css");/d' "$dir/chrome/userChrome.css" 2>/dev/null || true
    done < <(sed -n 's/^Path=//p' "$ini")
  done
  rm -rf "$HOME/.cache/ksvg-elements" "$HOME"/.cache/plasma_theme_*.kcache "$HOME/.cache/icon-cache.kcache"
}
in_use=false
for setting in "kdeglobals KDE LookAndFeelPackage" "plasmarc Theme name" "kdeglobals General ColorScheme" \
    "kdeglobals Icons Theme"; do
  set -- $setting
  case $(kreadconfig6 --file "$1" --group "$2" --key "$3" 2>/dev/null) in Lagoon|Teal) in_use=true ;; esac
done
if $in_use; then step "Going back to Breeze Dark (your panels stay)" back_to_breeze; fi
step "Removing Lagoon, Teal Pill and the Teal icons" remove_lagoon
cat <<EOF

Lagoon is removed. If Teal Pill was in a panel, remove its empty slot (right-click it,
Remove). Restart the apps already open to see Breeze everywhere.
EOF
