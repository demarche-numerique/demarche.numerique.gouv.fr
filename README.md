# assets

Orphan branch hosting images (screenshots, diagrams) referenced from GitHub
issues and pull requests. It shares no history with `main` and must never be
merged into it.

## Adding an image

```sh
gh api --method PUT \
  repos/demarche-numerique/demarche.numerique.gouv.fr/contents/screenshots/<name>.png \
  -f branch=assets \
  -f message="add <name>.png" \
  -f content="$(base64 -i <local-file>.png | tr -d '\n')"
```

Then reference it from an issue or PR body:

```markdown
![description](https://raw.githubusercontent.com/demarche-numerique/demarche.numerique.gouv.fr/assets/screenshots/<name>.png)
```

## Conventions

- Name files `<issue-or-pr-number>-<slug>.png` so they can be traced back.
- Everything here is public and permanent. Never upload screenshots containing
  real dossier data, personal data or credentials — use GitHub's own
  drag-and-drop attachment upload for those.
