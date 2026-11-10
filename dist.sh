#!/usr/bin/env bash
# Prépare l'archive à distribuer : dist/Lagoon.tar.gz
# (thème construit, icônes Teal construites, install.sh, README, LICENSE, CREDITS).
set -euo pipefail

HERE=$(dirname "$(realpath "$0")")
OUT=$HERE/dist/Lagoon

# Teal Pill est une copie de son dépôt : s'il est à côté, elle doit en être le dernier commit
# (tools/sync-pill.sh la refait). Sans cela, l'archive embarquerait une pilule périmée.
PILL=$HERE/../teal-pill
if [ -d "$PILL/.git" ]; then
  fresh=$(mktemp -d)
  git -C "$PILL" archive HEAD package po LICENSE | tar -x -C "$fresh"
  if ! diff -rq "$fresh" "$HERE/vendor/teal-pill" >/dev/null; then
    rm -rf "$fresh"
    echo "vendor/teal-pill n'est pas le dernier commit de ../teal-pill : lancer tools/sync-pill.sh" >&2
    exit 1
  fi
  rm -rf "$fresh"
fi

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
