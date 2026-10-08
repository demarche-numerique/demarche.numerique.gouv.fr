#!/usr/bin/env bash
# Lists the PRs to (re)assess and their criticality state.
# The assessment comment is found by its marker, whoever posted it.
# Usage: state.sh            -> open PRs labelled "autonome"
#        state.sh 14220 ...  -> only these PRs
# TSV columns: number, status, head sha, assessed sha, comment id, marker level, current label, title
#   status: nouvelle (never assessed) | à-réévaluer (new commits since) | à-jour
set -euo pipefail

repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)

if [ $# -gt 0 ]; then
  numbers="$*"
else
  numbers=$(gh pr list --label autonome --state open --limit 100 --json number -q '.[].number')
fi

for n in $numbers; do
  pr=$(gh pr view "$n" --json headRefOid,title,labels)
  head=$(jq -r .headRefOid <<<"$pr")
  title=$(jq -r .title <<<"$pr")
  label=$(jq -r '[.labels[].name | select(startswith("criticité:"))] | join(",") | if . == "" then "-" else . end' <<<"$pr")

  comment=$(gh api --paginate "repos/$repo/issues/$n/comments" \
    | jq -s '[.[][] | select(.body | contains("<!-- criticite-pr "))] | last // empty')

  if [ -z "$comment" ]; then
    printf '%s\tnouvelle\t%s\t-\t-\t-\t%s\t%s\n' "$n" "$head" "$label" "$title"
    continue
  fi

  id=$(jq -r .id <<<"$comment")
  marker=$(jq -r '.body | capture("<!-- criticite-pr sha=(?<sha>[0-9a-f]+) niveau=(?<niveau>[a-z]+) -->")' <<<"$comment")
  sha=$(jq -r .sha <<<"$marker")
  niveau=$(jq -r .niveau <<<"$marker")
  status=$([ "$sha" = "$head" ] && echo "à-jour" || echo "à-réévaluer")
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$status" "$head" "$sha" "$id" "$niveau" "$label" "$title"
done
