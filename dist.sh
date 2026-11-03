#!/usr/bin/env bash
# Prépare l'archive à distribuer : dist/Lagoon.tar.gz
# (thème construit, icônes Teal construites, install.sh, README, LICENSE, CREDITS).
set -euo pipefail

HERE=$(dirname "$(realpath "$0")")
OUT=$HERE/dist/Lagoon

rm -rf "$HERE/dist"
mkdir -p "$OUT"
DEST=$OUT/share "$HERE/build.sh"
cp "$HERE"/{install.sh,uninstall.sh,README.md,LICENSE,CREDITS.md} "$OUT/"
cp -r "$HERE/extras" "$OUT/"
# Teal, the icon theme, built: its own release archive (TEAL_ARCHIVE=<file> to use a local one)
if [ -z "${TEAL_ARCHIVE:-}" ]; then
  TEAL_ARCHIVE=$HERE/dist/teal-icons.tar.gz
  curl -fsSL -o "$TEAL_ARCHIVE" \
    https://github.com/elomkdn/teal-icons/releases/latest/download/teal-icons.tar.gz
fi
tar -xzf "$TEAL_ARCHIVE" -C "$OUT"
chmod +x "$OUT/install.sh" "$OUT/uninstall.sh"
tar -czf "$HERE/dist/Lagoon.tar.gz" -C "$HERE/dist" Lagoon
echo "Archive : $HERE/dist/Lagoon.tar.gz"
