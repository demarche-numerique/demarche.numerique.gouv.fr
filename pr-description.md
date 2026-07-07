---
title: "Tech: extraire les textes en dur de Attachment::FileInputComponent vers i18n"
---

# Probleme

Textes francais en dur dans `app/components/attachment/file_input_component.rb` — bloque l'internationalisation et l'accessibilite (les lecteurs d'ecran dependent des traductions structurees).

# Solution

Skill [`/i18n-hardcoded`](https://github.com/mfo/night-shift/blob/main/.claude/skills/i18n-hardcoded/SKILL.md)

**Aucun texte hardcode trouve** — le fichier ne contient que des chaines techniques (classes CSS, attributs HTML, data attributes, noms de methodes). Aucune extraction i18n necessaire.

### Validation technique

- [x] Aucun texte francais en dur dans le fichier source
- [x] Toutes les chaines sont techniques (CSS, HTML attributes, data attributes, identifiants)

Generated with [Claude Code](https://claude.com/claude-code)
