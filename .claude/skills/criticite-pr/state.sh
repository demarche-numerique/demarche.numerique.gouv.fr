#!/usr/bin/env bash
# Lists the PRs to (re)assess and their criticality state.
# The assessment comment is found by its marker. The repository is public and
# any account can comment, so only markers posted by an account with push
# access are used; markers from other accounts are counted, not used.
# Usage: state.sh 14220
# TSV columns: number, status, head sha, assessed sha, comment id, marker level, current label, foreign markers, title
#   status: nouvelle (never assessed) | à-réévaluer (new commits since) | à-jour
set -euo pipefail

repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
me=$(gh api user -q .login)

n=${1:?usage: state.sh <PR number>}

pr=$(gh pr view "$n" --json headRefOid,title,labels)
head=$(jq -r .headRefOid <<<"$pr")
title=$(jq -r .title <<<"$pr")
label=$(jq -r '[.labels[].name | select(startswith("criticité:"))] | join(",") | if . == "" then "-" else . end' <<<"$pr")

markers=$(gh api --paginate "repos/$repo/issues/$n/comments" \
  | jq -s '[.[][] | select(.body | contains("<!-- criticite-pr "))]')

# Trusted authors: the account running the skill, plus anyone who can push to
# the repository (a teammate who ran the skill). author_association is not
# used: CONTRIBUTOR covers any external author with a merged commit, and
# MEMBER depends on the visibility of the organisation membership.
trusted=("$me")
for login in $(jq -r --arg me "$me" '[.[].user.login | select(. != $me)] | unique | .[]' <<<"$markers"); do
  permission=$(gh api "repos/$repo/collaborators/$login/permission" -q .permission 2>/dev/null || echo none)
  case "$permission" in
    admin|write) trusted+=("$login") ;;
  esac
done
trusted_json=$(printf '%s\n' "${trusted[@]}" | jq -R . | jq -s .)

comment=$(jq --argjson trusted "$trusted_json" '[.[] | select(.user.login as $u | $trusted | index($u))] | last // empty' <<<"$markers")
foreign=$(jq --argjson trusted "$trusted_json" '[.[] | select(.user.login as $u | $trusted | index($u) | not)] | length' <<<"$markers")

if [ -z "$comment" ]; then
  printf '%s\tnouvelle\t%s\t-\t-\t-\t%s\t%s\t%s\n' "$n" "$head" "$label" "$foreign" "$title"
  exit 0
fi

id=$(jq -r .id <<<"$comment")
marker=$(jq -r '.body | capture("<!-- criticite-pr sha=(?<sha>[0-9a-f]+) niveau=(?<niveau>[a-z]+) -->")' <<<"$comment")
sha=$(jq -r .sha <<<"$marker")
niveau=$(jq -r .niveau <<<"$marker")
status=$([ "$sha" = "$head" ] && echo "à-jour" || echo "à-réévaluer")
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$status" "$head" "$sha" "$id" "$niveau" "$label" "$foreign" "$title"
