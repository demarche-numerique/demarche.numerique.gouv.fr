#!/usr/bin/env bash
# Arrête le serveur de recette, supprime le worktree et la base de la PR.
# Usage : cleanup.sh <numéro de PR>
set -euo pipefail

PR="${1:?usage: cleanup.sh <numéro de PR>}"
ROOT="$(git rev-parse --show-toplevel)"
WT="$(dirname "$ROOT")/review-pr-$PR"

for port in "${RECETTE_PORT:-3100}" "${RECETTE_VITE_PORT:-3136}"; do
  for pid in $(lsof -tiTCP:"$port" -sTCP:LISTEN || true); do
    [ "$(lsof -a -p "$pid" -d cwd -Fn | sed -n 's/^n//p')" = "$WT" ] && kill "$pid"
  done
done
[ -d "$WT" ] && git -C "$ROOT" worktree remove --force "$WT"
dropdb --if-exists -h localhost "tps_review_pr_$PR"
psql_test_db="tps_test_review_pr_$PR"  # créée par le hook post-checkout, s'il est installé
dropdb --if-exists -h localhost -U tps_test "$psql_test_db" 2>/dev/null || true
echo "recette PR $PR nettoyée"
