---
title: "IDOR procedure_id tampering dans le flow de confirmation administrateur"
source: harden-pentest
date: 2026-04-14
owasp: A01
cwe: CWE-639
dread_score: 10/15
verdict: backlog
status: fixed
fixed_date: 2026-04-14
category: security
confidence: high
chain_verified: true
test_vector: "POST /manager/procedures/999/administrateur_confirmations?q=<token_genere_pour_procedure_42>"
affected_files:
  - app/controllers/manager/confirmation_urls_controller.rb:11
  - app/controllers/manager/administrateur_confirmations_controller.rb:14-18
  - app/controllers/manager/administrateur_confirmations_controller.rb:36-42
  - app/controllers/manager/administrateur_confirmations_controller.rb:50-52
---

## Contexte

Le back-office super admin dispose d'un flow de confirmation "4 yeux" pour ajouter un administrateur tiers a une procedure. Le super admin A genere un lien chiffre contenant l'email de l'admin a ajouter et son propre ID. Un super admin B (different de A et de l'invite) doit confirmer en visitant ce lien.

Le token chiffre (`params[:q]`) ne contient que `{ email, inviter_id }`. Le `procedure_id` provient uniquement de l'URL et n'est jamais valide contre le token.

## Classification

- **OWASP A01** — Broken Access Control (IDOR / parameter tampering)
- **CWE-639** — Authorization Bypass Through User-Controlled Key

### DREAD (10/15)

| Axe | Score | Justification |
|---|---|---|
| Damage | 2 | Ajoute un admin arbitraire a n'importe quelle procedure. Meme resultat atteignable via chemin legitime (super admin s'ajoute puis ajoute l'autre). |
| Reproducibility | 3 | Deterministe : editer le procedure_id dans l'URL suffit |
| Exploitability | 1 | Requiert super admin authentifie avec 2FA + reception d'un lien de confirmation valide |
| Affected users | 2 | Toutes les procedures sont ciblables |
| Discoverability | 2 | procedure_id visible dans l'URL, pattern de tampering classique |

## Faille expliquee

**Analogie :** Un bon de commande signe qui dit "livrer a Jean" mais sans preciser l'adresse. L'adresse est ecrite au crayon sur l'enveloppe -- n'importe qui peut l'effacer et en ecrire une autre.

### Flow vulnerable

```
ConfirmationUrlsController#new (Super Admin A)
  → encrypt({ email: "admin@example.com", inviter_id: 42 })
  → URL: /manager/procedures/100/administrateur_confirmations/new?q=<token>

AdministrateurConfirmationsController#create (Super Admin B)
  → set_procedure: Procedure.find(params[:procedure_id])  ← PREND L'ID DE L'URL
  → decrypt_params: extrait email + inviter_id             ← PAS DE CHECK procedure_id
  → AdministrateursProcedure.create!(procedure: @procedure, administrateur: ...)
```

Super Admin B change `100` en `999` dans l'URL → admin@example.com est ajoute a la procedure 999.

## STR (Steps To Reproduce)

1. Super Admin A visite `/manager/procedures/42/confirmation_urls/new?email=admin@example.com`
2. Le systeme genere un lien : `/manager/procedures/42/administrateur_confirmations/new?q=<token>`
3. Super Admin A envoie ce lien a Super Admin B
4. Super Admin B modifie l'URL : change `42` en `999`
5. Super Admin B visite `/manager/procedures/999/administrateur_confirmations/new?q=<token>`
6. Super Admin B confirme (POST create)
7. **Resultat :** admin@example.com est ajoute a la procedure 999 au lieu de 42

**Attendu :** Le token devrait etre invalide car il a ete genere pour la procedure 42, pas 999.

## Impact reel

- Un super admin confirmeur peut ajouter un administrateur a **n'importe quelle** procedure, pas seulement celle prevue par l'inviter
- Le controle 4 yeux est contourne sur le scope de la procedure
- **Facteur attenuant majeur :** les super admins peuvent deja s'ajouter eux-memes a n'importe quelle procedure via `add_administrateur_and_instructeur`, puis ajouter d'autres admins. Le bypass n'offre pas de privilege fondamentalement nouveau, mais contourne un controle d'audit interne.

## Analyse technique

### Fichiers impactes

1. **`app/controllers/manager/confirmation_urls_controller.rb:11`** — Le token est genere sans `procedure_id` :
   ```ruby
   q: encrypt({ email: params[:email], inviter_id: current_super_admin.id })
   ```

2. **`app/controllers/manager/administrateur_confirmations_controller.rb:36-42`** — `decrypt_params` n'extrait que `email` et `inviter_id`, pas de validation du `procedure_id` :
   ```ruby
   def decrypt_params
     @inviter_id = decrypted_params[:inviter_id]
     @invited_email = decrypted_params[:email]
   end
   ```

3. **`app/controllers/manager/administrateur_confirmations_controller.rb:50-52`** — `set_procedure` prend le `procedure_id` de l'URL sans validation :
   ```ruby
   def set_procedure
     @procedure = Procedure.with_discarded.find(params[:procedure_id])
   end
   ```

### Root cause

Le `procedure_id` n'est pas lie cryptographiquement au token. Le token authentifie l'email et l'inviter, mais pas la procedure cible.

### Chaine d'appels

| Niveau | Fichier:ligne | Protection | Verdict |
|---|---|---|---|
| Route | config/routes.rb:33 | authenticate_super_admin! (herite) | Super admin requis |
| Encrypt | confirmation_urls_controller.rb:11 | Token = {email, inviter_id} | procedure_id absent |
| set_procedure | administrateur_confirmations_controller.rb:50-52 | Procedure.find(params[:procedure_id]) | Aucune validation vs token |
| decrypt_params | administrateur_confirmations_controller.rb:36-42 | Extrait email + inviter_id | Pas de check procedure_id |
| ensure_not_inviter | administrateur_confirmations_controller.rb:23-24 | Check identite | Pas de check procedure |
| ensure_not_invited | administrateur_confirmations_controller.rb:27-28 | Check identite | Pas de check procedure |
| create | administrateur_confirmations_controller.rb:14-18 | Aucune | Vulnerable |

## Recommandation

**Verdict : backlog priorise** (10/15)

Inclure `procedure_id` dans le token chiffre et valider la correspondance dans `decrypt_params`. Fix trivial, pas d'urgence car restreint aux super admins authentifies 2FA.
