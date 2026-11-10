#!/usr/bin/env bash
# Publie les archives sur leurs releases « latest », dans l'ordre où elles dépendent l'une de
# l'autre : Teal Pill, puis Teal, puis Lagoon, qui embarque les deux. Chaque dépôt doit être
# propre et poussé : ce qui est publié est ce qui est sur GitHub. Les dépôts sont côte à côte
# (../teal-pill, ../teal-icons, et ../spicetify-teal s'il est là).
#
# usage : tools/release.sh [--dry-run]    (--dry-run : tout sauf l'envoi, même sur des dépôts
#                                          pas encore commités ou poussés : une répétition)
#
# Les releases n'ont pas de numéro : l'archive est remplacée, l'étiquette « latest » ne bouge pas.
set -euo pipefail

HERE=$(realpath "$(dirname "$(realpath "$0")")/..")
ROOT=$(dirname "$HERE")
dry=false
[ "${1:-}" = --dry-run ] && dry=true

refuse() { # à blanc, un dépôt pas prêt n'arrête rien
  if $dry; then echo "  (à blanc) $1"; else echo "$1" >&2; exit 1; fi
}

ready() { # dépôt : propre, et son dernier commit est sur GitHub
  local repo=$ROOT/$1
  [ -d "$repo/.git" ] || { echo "$1 : dépôt absent de $ROOT" >&2; exit 1; }
  [ -z "$(git -C "$repo" status --porcelain)" ] || refuse "$1 : des changements ne sont pas commités"
  git -C "$repo" fetch -q origin
  [ "$(git -C "$repo" rev-parse HEAD)" = "$(git -C "$repo" rev-parse origin/main)" ] ||
    refuse "$1 : son dernier commit n'est pas sur origin/main"
}

publish() { # dépôt, archive
  if $dry; then
    echo "  (à blanc) $1 : $2 n'est pas envoyée"
  else
    (cd "$ROOT/$1" && gh release upload latest "$2" --clobber)
    echo "  $1 : $(basename "$2") publiée"
  fi
}

for repo in teal-pill teal-icons lagoon-kde; do ready "$repo"; done

echo "Teal Pill"
(cd "$ROOT/teal-pill" && ./dist.sh >/dev/null)
publish teal-pill "$ROOT/teal-pill/dist/teal-pill.plasmoid"

echo "Teal"
[ ! -x "$ROOT/teal-icons/make/check.sh" ] || "$ROOT/teal-icons/make/check.sh"
(cd "$ROOT/teal-icons" && ./dist.sh >/dev/null)
publish teal-icons "$ROOT/teal-icons/dist/teal-icons.tar.gz"

echo "Lagoon"
"$HERE/tools/check.sh"
# avec l'archive de Teal qui vient d'être faite, et la copie de Teal Pill vérifiée par dist.sh
TEAL_ARCHIVE=$ROOT/teal-icons/dist/teal-icons.tar.gz "$HERE/dist.sh" >/dev/null
publish lagoon-kde "$HERE/dist/Lagoon.tar.gz"

# le thème Spotify n'a pas d'archive : le Marketplace lit user.css sur jsDelivr, qui garde
# l'ancien jusqu'à 12 h si on ne le purge pas
if [ -d "$ROOT/spicetify-teal/.git" ] && ! $dry; then
  curl -fsS https://purge.jsdelivr.net/gh/elomkdn/spicetify-teal@main/user.css >/dev/null &&
    echo "Spotify : cache de jsDelivr purgé (à refaire dans quelques minutes si Spotify garde l'ancien)"
fi
