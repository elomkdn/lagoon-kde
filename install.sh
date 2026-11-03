#!/usr/bin/env bash
# Installs Lagoon for the current user (~/.local/share), from a release archive or
# from a clone of the repository (the theme is then built first, in a temporary folder).
#
# usage: ./install.sh [--klassy] [--firefox] [--no-icons] [--apply | --no-apply]
#   --klassy      use the Klassy window decoration with rounded corners (15 px)
#                 instead of the square Catppuccin one; Klassy must be installed
#   --firefox     give Firefox's window buttons the theme's red, yellow and green dots, with a
#                 userChrome.css in each Firefox profile (an existing one is kept)
#   --no-icons    keep your icon theme: Teal, the theme's icons, is neither installed nor selected
#   --apply       apply Lagoon at the end without asking (its layout too: --apply-layout)
#   --no-apply    install only, without asking; apply it later from System Settings
#   --uninstall   the same as ./uninstall.sh: remove Lagoon, Teal Pill and the Teal icons
#
# In a terminal, the installer shows each step as it runs, and asks at the end whether to apply
# Lagoon now, and whether to replace your panels with its top bar and dock.
#
# The Kvantum application style (the libadwaita look for Qt apps) is part of the theme:
# the global theme selects Kvantum, and this script selects its Lagoon theme.
# Kvantum (package 'kvantum') is recommended, not required: without it, Qt apps keep Breeze
# in the theme's colors. The GTK theme is selected too (GTK 3/4
# settings, which KDE keeps in sync, gsettings and xsettingsd): a global theme cannot do it.
# libadwaita (GNOME) apps ignore GTK themes: they get the theme's colors from one line in
# ~/.config/gtk-4.0/gtk.css.
set -euo pipefail

HERE=$(dirname "$(realpath "$0")")
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
THEME=Lagoon

klassy=false
firefox=false
icons=true
uninstall=false
apply=ask       # ask, yes, no
layout=ask      # ask, yes, no
# Teal, the icon theme that comes with Lagoon (github.com/elomkdn/teal-icons)
for arg in "$@"; do
  case $arg in
    --gtk) ;;  # older option: the GTK theme is now always selected
    --libadwaita) ;;  # older option: libadwaita apps are now always themed
    --klassy) klassy=true ;;
    --firefox) firefox=true ;;
    --no-icons) icons=false ;;
    --apply) apply=yes; [ "$layout" = ask ] && layout=no ;;
    --apply-layout) apply=yes; layout=yes ;;
    --no-apply) apply=no ;;
    --uninstall) uninstall=true ;;
    --kvantum) ;;  # older option: Kvantum is now always set up
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

# --- how the steps show ---------------------------------------------------------------------
# In a terminal, a step runs in the background while a spinner turns, then shows ✓ or ✗ (with
# what went wrong); elsewhere (a script, a log), the steps just print their name.
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

ask() { # question, default (y or n) -> 0 for yes
  local answer hint="[Y/n]"
  [ "$2" = n ] && hint="[y/N]"
  printf '%s %s ' "$1" "$hint"
  read -r answer || answer=""
  case ${answer:-$2} in [YyOo]*) return 0 ;; *) return 1 ;; esac
}

$interactive && printf '\n  \033[1mLagoon\033[0m, for the KDE Plasma desktop\n\n'

# --- uninstall: uninstall.sh, next to this script --------------------------------------------

if $uninstall; then
  exec "$HERE/uninstall.sh"
fi

# --- the theme --------------------------------------------------------------------------------

# From a clone of the repository: build the theme first
SRC=$HERE/share
if [ ! -d "$SRC" ]; then
  missing=()
  command -v rsvg-convert >/dev/null || missing+=(librsvg)
  command -v python3 >/dev/null || missing+=(python)
  if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing packages to build the theme: sudo pacman -S ${missing[*]}" >&2
    exit 1
  fi
  SRC=$WORK/share
  step "Building the theme (about 30 s)" env DEST="$SRC" "$HERE/build.sh"
fi

# Copy the built files, replacing any previous version
PARTS=(
  plasma/look-and-feel/Lagoon                               # global theme (layout, splash)
  plasma/desktoptheme/Lagoon                                # Plasma theme
  icons/catppuccin-mocha-teal-cursors                       # cursors (Catppuccin Mocha Teal)
  color-schemes/Lagoon.colors                               # color scheme
  aurorae/themes/CatppuccinMocha-Classic                    # window decoration
  themes/$THEME                                             # GTK theme
  wallpapers/Lagoon                                         # wallpaper
  wallpapers/Lagoon-Glow                                    # second wallpaper
  wallpapers/Lagoon-Waves                                   # the lock screen's, without the logo
  plasma/layout-templates/com.github.elomkdn.lagoon.dock    # "Add panel" templates
  plasma/layout-templates/com.github.elomkdn.lagoon.topbar
  plasma/plasmoids/com.github.elomkdn.tealpill              # Teal Pill, the top bar's music island
  icons/hicolor/scalable/apps/lagoon-launcher.svg           # the launcher's icon
)
copy_parts() {
  local part
  for part in "${PARTS[@]}"; do
    rm -rf "${DATA:?}/$part"
    mkdir -p "$(dirname "$DATA/$part")"
    cp -r "$SRC/$part" "$DATA/$part"
  done
  # the cursor page of System Settings looks in ~/.icons, not in ~/.local/share/icons
  if [ "$DATA" = "$HOME/.local/share" ] && [ ! -e "$HOME/.icons/catppuccin-mocha-teal-cursors" ]; then
    mkdir -p "$HOME/.icons"
    ln -s "$DATA/icons/catppuccin-mocha-teal-cursors" "$HOME/.icons/catppuccin-mocha-teal-cursors"
  fi
}
step "Installing the theme, its wallpapers and Teal Pill" copy_parts

# --- GTK and libadwaita apps ------------------------------------------------------------------

set_ini() { # file key value
  mkdir -p "$(dirname "$1")"
  touch "$1"
  grep -q '^\[Settings\]' "$1" || printf '[Settings]\n' >> "$1"
  if grep -q "^$2=" "$1"; then sed -i "s|^$2=.*|$2=$3|" "$1"; else sed -i "/^\[Settings\]/a $2=$3" "$1"; fi
}

setup_gtk() {
  # libadwaita apps ignore the GTK theme: they read its palette from the user stylesheet,
  # through one line that imports it. KDE rewrites this file at each login to add its own
  # import, which turned the links of earlier versions (--libadwaita) into frozen copies.
  local css=$CONFIG/gtk-4.0/gtk.css palette=$DATA/themes/$THEME/gtk-4.0/lagoon.css f
  mkdir -p "$CONFIG/gtk-4.0"
  for f in gtk.css gtk-dark.css assets; do
    if [ -L "$CONFIG/gtk-4.0/$f" ] && [[ $(readlink "$CONFIG/gtk-4.0/$f") == "$DATA/themes/$THEME/"* ]]; then
      rm "$CONFIG/gtk-4.0/$f"
    fi
  done
  if [ -f "$css" ] && grep -q 'ripple-on-headerbar' "$css"; then rm "$css"; fi  # frozen copy
  touch "$css"
  { echo "@import url(\"file://${palette// /%20}\");"; grep -v "/themes/$THEME/gtk-4.0/" "$css" || true; } > "$css.new"
  mv "$css.new" "$css"

  # Flatpak apps only see the theme, and the line above, if they may read them
  if command -v flatpak >/dev/null; then
    flatpak override --user --filesystem=xdg-data/themes:ro --filesystem=xdg-config/gtk-4.0:ro
  fi

  set_ini "$CONFIG/gtk-3.0/settings.ini" gtk-theme-name "$THEME"
  set_ini "$CONFIG/gtk-4.0/settings.ini" gtk-theme-name "$THEME"
  if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme "$THEME" || true
    # GTK apps on Wayland read gsettings. A stuck dconf service accepts changes without saving
    # them: GTK apps then keep an old theme, font and cursor size. Restart it once if needed.
    if [ "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)" != "'$THEME'" ]; then
      pkill -x dconf-service 2>/dev/null || true
      gsettings set org.gnome.desktop.interface gtk-theme "$THEME" || true
    fi
    if [ "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)" != "'$THEME'" ]; then
      touch "$WORK/dconf-stuck"
    elif [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && command -v qdbus6 >/dev/null; then
      # let KDE copy its fonts, icons and cursor to GTK again (they may be stale after such a stall)
      qdbus6 org.kde.kded6 /kded org.kde.kded6.unloadModule gtkconfig >/dev/null 2>&1 &&
        qdbus6 org.kde.kded6 /kded org.kde.kded6.loadModule gtkconfig >/dev/null 2>&1 || true
    fi
  fi
  local x=$CONFIG/xsettingsd/xsettingsd.conf
  if [ -f "$x" ]; then
    sed -i "s|^Net/ThemeName .*|Net/ThemeName \"$THEME\"|" "$x"
    pkill -HUP xsettingsd 2>/dev/null || true
  fi
}
step "Theming GTK and GNOME apps" setup_gtk
if [ -e "$WORK/dconf-stuck" ]; then
  note "dconf does not save GTK settings: log out and back in, then run this script again."
fi

# --- Kvantum ----------------------------------------------------------------------------------

setup_kvantum() {
  # the Kvantum theme ships with the GTK theme, in themes/$THEME/Kvantum, where Kvantum finds
  # it. The global theme cannot write Kvantum's own config; applying it again keeps this one.
  local kv=$CONFIG/Kvantum/kvantum.kvconfig
  if [ "$(kreadconfig6 --file "$kv" --group General --key theme 2>/dev/null)" != "$THEME" ]; then
    mkdir -p "$(dirname "$kv")"
    [ -f "$kv" ] && cp "$kv" "$kv.bak"
    kwriteconfig6 --file "$kv" --group General --key theme "$THEME"
  fi
  # before 1.2, Dolphin and the portal had a variant of their own: every app has its colors now
  kwriteconfig6 --file "$kv" --group Applications --key "$THEME-KIO" --delete 2>/dev/null || true
  rm -rf "${DATA:?}/themes/$THEME-KIO"
}
step "Setting up the Qt style (Kvantum)" setup_kvantum
kvantum_ok=true
if ! ls /usr/lib*/qt6/plugins/styles/libkvantum.so >/dev/null 2>&1; then
  kvantum_ok=false
  note "Kvantum is not installed: Qt apps keep Breeze, in the theme's colors (optional)."
fi

# --- Teal, the icon theme ---------------------------------------------------------------------

# the icon theme before Lagoon's, to keep it with --no-icons when the global theme is applied
previous_icons=$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null || true)

if $icons; then
  TEAL=$HERE/teal-icons
  if [ ! -x "$TEAL/install.sh" ]; then
    # a clone of the repository: Teal's own release archive
    fetch_teal() {
      local url=https://github.com/elomkdn/teal-icons/releases/latest/download/teal-icons.tar.gz
      command -v curl >/dev/null && curl -fsSL "$url" -o "$WORK/teal.tar.gz" \
        && tar -xzf "$WORK/teal.tar.gz" -C "$WORK"
    }
    if (interactive=false; fetch_teal) 2>/dev/null; then
      TEAL=$WORK/teal-icons
      $interactive && printf '  \033[32m✓\033[0m %s\n' "Downloading the Teal icons"
    else
      TEAL=""
      note "The Teal icons could not be downloaded: Lagoon is installed without them."
      note "Run ./install.sh again when online, or use the release archive, which has them."
    fi
  fi
  if [ -n "$TEAL" ]; then
    step "Installing the Teal icons (a few thousand files)" "$TEAL/install.sh" --set
  fi
fi

# --- Klassy and Firefox -----------------------------------------------------------------------

set_klassy() {
  local rc=$CONFIG/klassy/klassyrc
  mkdir -p "$(dirname "$rc")"
  [ -f "$rc" ] && [ ! -f "$rc.bak" ] && cp "$rc" "$rc.bak"
  cp "$HERE/extras/klassy/klassyrc" "$rc"
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.klassy
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Klassy
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize None
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto false
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft XIA
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight EHFSM
  qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
}
if $klassy; then
  if ! ls /usr/lib*/qt6/plugins/org.kde.kdecoration3/org.kde.klassy.so >/dev/null 2>&1; then
    echo "Klassy is not installed: install it first (https://github.com/paulmcauley/klassy)" >&2
    exit 1
  fi
  step "Selecting Klassy, rounded windows (15 px)" set_klassy
fi

# Firefox draws its window buttons itself, out of reach of GTK themes: a userChrome.css gives
# them the dots (Firefox reads it once toolkit.legacyUserProfileCustomizations.stylesheets is set)
set_firefox() {
  local ini path dir chrome
  for ini in "$CONFIG/mozilla/firefox/profiles.ini" "$HOME/.mozilla/firefox/profiles.ini"; do
    [ -f "$ini" ] || continue
    while IFS= read -r path; do
      case $path in /*) dir=$path ;; *) dir=$(dirname "$ini")/$path ;; esac
      [ -d "$dir" ] || continue
      mkdir -p "$dir/chrome"
      cp "$HERE/extras/firefox/lagoon.css" "$dir/chrome/lagoon.css"
      chrome=$dir/chrome/userChrome.css
      touch "$chrome"
      if ! grep -q 'lagoon.css' "$chrome"; then
        { echo '@import url("lagoon.css");'; cat "$chrome"; } > "$chrome.new"
        mv "$chrome.new" "$chrome"
      fi
      grep -qs 'legacyUserProfileCustomizations.stylesheets' "$dir/user.js" ||
        echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$dir/user.js"
    done < <(sed -n 's/^Path=//p' "$ini")
  done
}
if $firefox; then
  step "Giving Firefox's window buttons the dots (restart Firefox)" set_firefox
fi

# --- apply it now? ----------------------------------------------------------------------------

in_plasma=false
[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && command -v plasma-apply-lookandfeel >/dev/null && in_plasma=true

if $in_plasma && [ "$apply" = ask ]; then
  if $interactive; then
    echo
    if ask "  Apply Lagoon now?" y; then
      apply=yes
      if [ "$layout" = ask ]; then
        ask "  Also replace your panels with Lagoon's top bar and dock?" n && layout=yes || layout=no
      fi
    else
      apply=no
    fi
    echo
  else
    apply=no
  fi
fi

set_lock_screen() {
  # behind the avatar and the password, the logo would blur into a stain; a wallpaper the user
  # chose for the lock screen stays
  local lock=(--file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General)
  [ -z "$(kreadconfig6 "${lock[@]}" --key Image 2>/dev/null)" ] || return 0
  kwriteconfig6 "${lock[@]}" --key Image "file://$DATA/wallpapers/Lagoon-Waves"
  kwriteconfig6 "${lock[@]}" --key PreviewImage "file://$DATA/wallpapers/Lagoon-Waves"
}

apply_lagoon() {
  set_lock_screen
  if [ "$layout" = yes ]; then
    plasma-apply-lookandfeel -a Lagoon --resetLayout
  else
    plasma-apply-lookandfeel -a Lagoon
  fi
  # the global theme selects Teal and the square Catppuccin decoration: keep the user's choices
  if ! $icons && [ -n "$previous_icons" ]; then
    /usr/lib/plasma-changeicons "$previous_icons" 2>/dev/null ||
      kwriteconfig6 --file kdeglobals --group Icons --key Theme "$previous_icons"
  fi
  if $klassy; then set_klassy; fi
}

if $in_plasma && [ "$apply" = yes ]; then
  step "Applying Lagoon$([ "$layout" = yes ] && echo ", with its top bar and dock")" apply_lagoon
  cat <<EOF

Lagoon is applied. Restart the apps already open to see it everywhere.
EOF
  $kvantum_ok || echo "Optional: Kvantum (sudo pacman -S kvantum) gives Qt apps the theme's look."
else
  cat <<EOF

Lagoon is installed. To apply it:
  - System Settings > Colors & Themes > Global Theme > "Lagoon"
    (tick "Desktop and window layout" to get the top bar and floating dock,
    or add them later: right-click the desktop > Add Panel),
  - or run ./install.sh --apply again.
EOF
  $kvantum_ok || echo "  - Optional: Kvantum (sudo pacman -S kvantum) gives Qt apps the theme's look."
  if $klassy; then
    echo "  - Applying the global theme from System Settings switches back to the square Catppuccin
    decoration: run ./install.sh --klassy again afterwards."
  fi
fi
