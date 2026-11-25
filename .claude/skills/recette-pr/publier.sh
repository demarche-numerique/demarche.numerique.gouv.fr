#!/usr/bin/env bash
set -euo pipefail

# Publie les captures d'une recette dans un gist public, puis écrit le commentaire de recette.
#   publier.sh <N> [--verdicts <resultats.json>] [--video <url user-attachments>] [--a-juger <fichier.md>]
# Les captures viennent du mode captures ; les verdicts aussi, sauf --verdicts (par exemple
# ceux de la recette guidée, tmp/recette/resultats-guide/resultats.json).
# Le gist est public : la session de l'agent peut le refuser, l'humain le lance alors par `!`.

PR="${1:?usage: publier.sh <numéro de PR> [--verdicts <resultats.json>] [--video <url>] [--a-juger <fichier.md>]}"
shift
SKILL="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
case "$ROOT" in */review-pr-*) ;; *) ROOT="$(dirname "$ROOT")/review-pr-$PR" ;; esac
DIR="$ROOT/tmp/recette"
CAPTURES="$DIR/resultats-captures"
VERDICTS="$CAPTURES/resultats.json"
OPTIONS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --verdicts) VERDICTS="$2"; shift 2 ;;
    *) OPTIONS+=("$1"); shift ;;
  esac
done

[ -f "$CAPTURES/resultats.json" ] || { echo "✗ pas de captures dans $CAPTURES : lancer d'abord recette.mjs --mode captures" >&2; exit 1; }
[ -f "$DIR/scenario.mjs" ] || { echo "✗ pas de scénario dans $DIR/scenario.mjs" >&2; exit 1; }

TRAVAIL="$(mktemp -d)"
trap 'rm -rf "$TRAVAIL"' EXIT
echo "Captures de la recette de la PR #$PR (/recette-pr)" > "$TRAVAIL/README.md"
URL="$(gh gist create --public --desc "Recette de la PR #$PR" "$TRAVAIL/README.md")"
ID="$(basename "$URL")"
gh auth setup-git
git clone --quiet "https://gist.github.com/$ID.git" "$TRAVAIL/gist"
cp "$CAPTURES"/*-consigne.png "$CAPTURES"/*-attendu.png "$TRAVAIL/gist/"
(cd "$TRAVAIL/gist" && git add -- *.png)
git -C "$TRAVAIL/gist" commit --quiet --no-gpg-sign -m "Captures de la recette"
git -C "$TRAVAIL/gist" push --quiet

USER_GH="$(gh api user --jq .login)"
node "$SKILL/commentaire.mjs" "$DIR/scenario.mjs" "$VERDICTS" "https://gist.githubusercontent.com/$USER_GH/$ID/raw" ${OPTIONS[@]+"${OPTIONS[@]}"} > "$DIR/commentaire.md"
echo "gist=$URL"
echo "commentaire=$DIR/commentaire.md"
