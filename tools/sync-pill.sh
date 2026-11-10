#!/usr/bin/env bash
# Recopie Teal Pill dans vendor/teal-pill : le dernier commit de son dépôt (package/, po/ et
# LICENSE), sans le catalogue compilé, que build.sh refait.
#
# usage : tools/sync-pill.sh [dépôt teal-pill ; par défaut ../teal-pill]
set -euo pipefail

HERE=$(dirname "$(realpath "$0")")/..
PILL=$(realpath "${1:-$HERE/../teal-pill}")
VENDOR=$HERE/vendor/teal-pill

rm -rf "$VENDOR/package" "$VENDOR/po"
mkdir -p "$VENDOR"
git -C "$PILL" archive HEAD package po LICENSE | tar -x -C "$VENDOR"
echo "vendor/teal-pill = $(git -C "$PILL" log -1 --format='%h %s')"
