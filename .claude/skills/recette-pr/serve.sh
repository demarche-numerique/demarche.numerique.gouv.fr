#!/usr/bin/env bash
# Lance Rails + Vite du worktree de recette, sur des ports distincts du serveur de dev
# (3000/3036) : sinon Rails servirait le JS de main via le Vite déjà lancé.
# Usage : serve.sh <numéro de PR>   (à lancer en arrière-plan)
set -euo pipefail

PR="${1:?usage: serve.sh <numéro de PR>}"
ROOT="$(git rev-parse --show-toplevel)"
case "$ROOT" in */review-pr-*) ;; *) ROOT="$(dirname "$ROOT")/review-pr-$PR" ;; esac
cd "$ROOT"

export RECETTE_PORT="${RECETTE_PORT:-3100}"
export DB_DATABASE="tps_review_pr_$PR"
export VITE_RUBY_PORT="${RECETTE_VITE_PORT:-3136}"
export APP_HOST="localhost:$RECETTE_PORT"
export RAILS_QUEUE_ADAPTER=async

rm -f tmp/pids/server.pid
trap 'kill 0' EXIT
bin/vite dev &
bin/rails server -p "$RECETTE_PORT" &
wait
