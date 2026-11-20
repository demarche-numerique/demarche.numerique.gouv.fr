#!/usr/bin/env bash
set -euo pipefail

for file in /app/bin/* /app/docker/*.sh; do
  [ -f "$file" ] || continue
  sed -i 's/\r$//' "$file"
  chmod +x "$file"
done

bundle check || bundle install
bun install

exec "$@"
