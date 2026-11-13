#!/usr/bin/env bash
# Capture du bureau Lagoon tel qu'une installation neuve le donne, pour le README et les aperçus
# du thème global, sans toucher à la session en cours : le thème est installé dans un dossier
# personnel jetable, puis appliqué dans une session Plasma imbriquée et invisible (KWin en mode
# virtuel, son propre bus de session), où s'ouvrent Configuration du système et Dolphin pendant
# qu'un faux lecteur (mpris-standin.py) fait jouer un morceau pour Teal Pill.
#
# usage : tools/desktop-shot.sh <archive extraite (dist/Lagoon)> <sortie.png> [largeur hauteur]
# ex.   : ./dist.sh && tools/desktop-shot.sh dist/Lagoon /tmp/bureau.png
#
# Ce que la session imbriquée doit avoir pour ressembler à une vraie :
# - un XDG_RUNTIME_DIR au chemin court : celui des sockets (KIO, Wayland), limité à 108 caractères ;
# - ~/.config/kdedefaults dans XDG_CONFIG_DIRS, comme le fait startplasma : le thème global y écrit
#   ses choix (icônes, couleurs…), qui sans cela restent ceux de Breeze ;
# - XDG_DATA_HOME et XDG_CONFIG_HOME explicites, pas seulement HOME.
# Les ombres dessinées par Kirigami (la carte de Teal Pill) peuvent y sortir en aplat : la carte
# ouverte se capture sur un vrai bureau.
set -euo pipefail

HERE=$(dirname "$(realpath "$0")")
RELEASE=$(realpath "$1")
OUT=$(realpath -m "$2")
WIDTH=${3:-1920}
HEIGHT=${4:-1200}

WORK=$(mktemp -d)
RUN=$(mktemp -d /tmp/lgn.XXXXXX)
chmod 700 "$RUN"
trap 'rm -rf "$WORK" "$RUN"' EXIT
H=$WORK/home
mkdir -p "$H/.config" "$WORK/bin" "$H"/{Desktop,Documents,Downloads,Music,Pictures,Videos,Projects,Public,Templates}

# l'installeur règle aussi GTK par gsettings : un faux, pour ne pas écrire dans le vrai dconf
cat > "$WORK/bin/gsettings" <<'EOF'
#!/bin/sh
f="$HOME/.gsettings-$3"
case $1 in set) printf "'%s'\n" "$4" > "$f" ;; get) cat "$f" 2>/dev/null || echo "'Adwaita'" ;; esac
EOF
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/pkill"
chmod +x "$WORK/bin/gsettings" "$WORK/bin/pkill"

session=(env -i HOME="$H" XDG_DATA_HOME="$H/.local/share" XDG_CONFIG_HOME="$H/.config" XDG_CACHE_HOME="$H/.cache"
         XDG_STATE_HOME="$H/.local/state" XDG_RUNTIME_DIR="$RUN" XDG_CONFIG_DIRS="$H/.config/kdedefaults:/etc/xdg"
         USER="$USER" LANG=en_US.UTF-8 PATH=/usr/bin:/bin)

echo "Installation dans un dossier jetable…"
"${session[@]}" PATH="$WORK/bin:/usr/bin:/bin" DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent \
  "$RELEASE/install.sh" --no-apply > "$WORK/install.log" 2>&1 || { cat "$WORK/install.log" >&2; exit 1; }

# la place des deux fenêtres : KWin lit ses règles au démarrage
cat > "$H/.config/kwinrulesrc" <<EOF
[General]
count=3
rules=1,2,3

[1]
Description=systemsettings
wmclass=systemsettings
wmclassmatch=1
position=$((WIDTH * 60 / 1920)),70
positionrule=3
size=1010,690
sizerule=3

[2]
Description=dolphin
wmclass=org.kde.dolphin
wmclassmatch=1
position=$((WIDTH - 960)),$((HEIGHT * 130 / 1200))
positionrule=3
size=880,600
sizerule=3

[3]
Description=konsole
wmclass=org.kde.konsole
wmclassmatch=1
position=$((WIDTH * 90 / 1920)),$((HEIGHT - 440))
positionrule=3
size=760,320
sizerule=3
EOF

# ce que le terminal montre : ses couleurs, par fastfetch (sans la ligne utilisateur@machine)
cat > "$WORK/terminal.sh" <<'EOF'
#!/bin/sh
clear
fastfetch --logo-type small --structure "OS:Kernel:DE:WM:Theme:Icons:Cursor:Break:Colors" 2>/dev/null ||
  printf '\033[36mLagoon\033[0m\n'
exec sleep 600
EOF
chmod +x "$WORK/terminal.sh"

# une pochette pour le morceau : un coin du fond d'écran
python3 -I - "$H/.local/share/wallpapers/Lagoon/contents/images/1920x1080.png" "$WORK/cover.png" <<'EOF'
import sys
from PIL import Image
Image.open(sys.argv[1]).convert("RGB").crop((1220, 0, 1920, 700)).resize((512, 512)).save(sys.argv[2])
EOF

cat > "$WORK/session.sh" <<EOF
#!/bin/bash
exec > "$WORK/session.log" 2>&1
kbuildsycoca6 --noincremental 2>/dev/null
# l'environnement de la session, comme le donne startplasma : le plugin Qt du panneau
# Emplacements et le module GTK 3 (install.sh)
for f in "\$HOME"/.config/plasma-workspace/env/*.sh; do [ -r "\$f" ] && . "\$f"; done
# depuis un dossier neutre (voir install.sh)
(cd / && plasma-apply-lookandfeel -a Lagoon)
# les fenêtres arrondies de Klassy, comme le README les recommande, si Klassy est là
if ls /usr/lib*/qt6/plugins/org.kde.kdecoration3/org.kde.klassy.so >/dev/null 2>&1; then
  mkdir -p "\$HOME/.config/klassy" && cp "$RELEASE/extras/klassy/klassyrc" "\$HOME/.config/klassy/klassyrc"
  for kv in library=org.kde.klassy theme=Klassy BorderSize=None BorderSizeAuto=false ButtonsOnLeft=XIA ButtonsOnRight=EHFSM; do
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key "\${kv%%=*}" "\${kv#*=}"
  done
  qdbus6 org.kde.KWin /KWin reconfigure
fi
python3 "$HERE/mpris-standin.py" "$WORK/cover.png" &
plasmashell --no-respawn &
sleep 16
systemsettings &
sleep 6
(cd && konsole --profile Lagoon --hide-menubar --hide-tabbar -p LocalTabTitleFormat=Terminal -e "$WORK/terminal.sh") &
sleep 4
dolphin --select "\$HOME/Documents" &
sleep 8
spectacle -b -n -f -o "$WORK/shot.png"
sleep 2
kill \$(jobs -p) 2>/dev/null
sleep 1
EOF
chmod +x "$WORK/session.sh"

echo "Session Plasma imbriquée (une quarantaine de secondes)…"
timeout 180 "${session[@]}" XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 \
  dbus-run-session -- kwin_wayland --virtual --width "$WIDTH" --height "$HEIGHT" --no-lockscreen \
  --exit-with-session="$WORK/session.sh" > "$WORK/kwin.log" 2>&1 || true

if [ ! -s "$WORK/shot.png" ]; then
  echo "Pas de capture : voir ci-dessous." >&2
  tail -n 20 "$WORK/session.log" "$WORK/kwin.log" >&2
  exit 1
fi
mkdir -p "$(dirname "$OUT")"
cp "$WORK/shot.png" "$OUT"
echo "Capture : $OUT"
