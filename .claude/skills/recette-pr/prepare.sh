#!/usr/bin/env bash
# Prépare une recette : worktree détaché sur la tête de la PR, dépendances,
# base de dev dédiée rechargée depuis le schéma de la PR puis seedée (Oaken).
# Usage : prepare.sh <numéro de PR> [--keep-db]
set -euo pipefail

PR="${1:?usage: prepare.sh <numéro de PR> [--keep-db]}"
KEEP_DB="${2:-}"
ROOT="$(git rev-parse --show-toplevel)"
WT="$(dirname "$ROOT")/review-pr-$PR"
DB="tps_review_pr_$PR"

git -C "$ROOT" fetch --quiet origin "pull/$PR/head"
SHA="$(git -C "$ROOT" rev-parse FETCH_HEAD)"

if [ -d "$WT" ]; then
  git -C "$WT" checkout --quiet -- bun.lock  # réécrit par un `bun install` non figé
  if [ -n "$(git -C "$WT" status --porcelain --untracked-files=no)" ]; then
    echo "✗ $WT a des modifications locales : à régler avant de mettre à jour" >&2
    exit 1
  fi
  git -C "$WT" checkout --quiet --detach "$SHA"
else
  git -C "$ROOT" worktree add --quiet --detach "$WT" "$SHA"
fi

# Variables d'env locales (jamais commitées), sauf si un hook post-checkout les a posées.
# Pas d'initializer dev_auto_login : la recette se connecte avec un compte des seeds.
for f in .env .env.development.local; do
  if [ -f "$ROOT/$f" ] && [ ! -e "$WT/$f" ]; then cp "$ROOT/$f" "$WT/$f"; fi
done

cd "$WT"
bundle check >/dev/null || bundle install --quiet
git checkout --quiet -- bun.lock
if [ ! -e node_modules ] && cmp -s "$ROOT/bun.lock" bun.lock && [ -d "$ROOT/node_modules" ]; then
  ln -s "$ROOT/node_modules" node_modules  # mêmes dépendances que main : pas d'install
elif [ -L node_modules ] && ! cmp -s "$ROOT/bun.lock" bun.lock; then
  rm node_modules  # la PR change les dépendances : le lien vers main serait faux
  bun install --frozen-lockfile
elif [ ! -L node_modules ]; then
  bun install --frozen-lockfile >/dev/null
fi

if [ "$KEEP_DB" != "--keep-db" ]; then
  # Un serveur de recette encore lancé tient la base (db:drop échoue) et sert l'ancien code.
  # On n'arrête que les process lancés depuis ce worktree.
  for port in "${RECETTE_PORT:-3100}" "${RECETTE_VITE_PORT:-3136}"; do
    for pid in $(lsof -tiTCP:"$port" -sTCP:LISTEN || true); do
      if [ "$(lsof -a -p "$pid" -d cwd -Fn | sed -n 's/^n//p')" = "$WT" ]; then
        kill "$pid"; echo "serveur de recette arrêté (:$port) : relancer serve.sh"
      else
        echo "✗ :$port est occupé par un process hors de $WT : à arrêter à la main" >&2; exit 1
      fi
    done
  done
  sleep 1
  # SKIP_TEST_DATABASE : en development, db:drop/create/schema:load visent aussi la base
  # de test, qui serait ici celle du dépôt principal.
  DB_DATABASE="$DB" SKIP_TEST_DATABASE=1 bin/rails db:drop db:create db:schema:load db:seed >/dev/null
fi

echo "worktree=$WT"
echo "sha=$SHA"
echo "database=$DB"
