---
title: "Tech: optimiser les tests de procedure_cloning_spec"
---

# Probleme

Tests lents dans `spec/system/administrateurs/procedure_cloning_spec.rb` — temps baseline : 22.4s (médiane 3 runs locales).

# Solution

Skill [`/test-optimization`](https://github.com/mfo/night-shift/blob/main/.claude/skills/test-optimization/SKILL.md)

### Techniques appliquées

| Technique | Avant | Après | Gain |
|-----------|-------|-------|------|
| — | 22.4s | — | pas de gain mesurable |

Aucune technique n'a produit un gain > bruit de mesure (±2.4 % / ±0.53 s).

### Analyse

Ce fichier est une **system spec** dominée par le temps navigateur Playwright (~20s sur 22s). Le
setup applicatif est minimal : 1 `create(:procedure)` dans un `before` partagé par 2 scenarios.
Les techniques suivantes ont été évaluées :

| Technique | Raison du skip |
|-----------|----------------|
| T08 (let_it_be) | Gain < 5 % et < amplitude du bruit (±0.53 s) sur une spec système |
| T10 (let!→let) | Aucun `let!` dans le fichier |
| T13 (create → seed) | Déjà utilise `administrateurs.blank` ; les attributs de la procédure (libellé, path) sont le sujet du test |
| T04 (réduire setup) | Setup déjà minimal : 1 création par scénario |
| T01 (create→build) | Impossible — system spec a besoin des records en base |
| S01 (sleep) | `sleep 0.1` dans une boucle de polling download avec timeout — attente légitime |

**Résultat final : 22.4s → 22.4s (aucun gain mesurable)**

Coverage : 47.29 % → 47.29 % (maintenue)

Generated with [Claude Code](https://claude.com/claude-code)
