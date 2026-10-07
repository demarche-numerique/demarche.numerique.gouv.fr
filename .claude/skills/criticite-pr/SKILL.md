---
name: criticite-pr
description: Évalue la criticité d'une ou plusieurs PR de demarche.numerique.gouv.fr (haute / moyenne / faible), pose le label criticité:* et un commentaire qui argumente le choix, et réévalue les PR qui ont reçu de nouveaux commits. À utiliser quand l'utilisateur demande la criticité, le niveau de risque ou le niveau de relecture d'une PR, veut labelliser les PR « autonome », ou lance /criticite-pr.
---

# Criticité des PR

Une PR reçoit **un seul** label parmi `criticité:haute`, `criticité:moyenne` et `criticité:faible`, accompagné d'**un seul** commentaire qui justifie le choix. Ce commentaire est édité sur place quand la PR évolue.

## 1. Lister ce qu'il y a à faire

```bash
bash .claude/skills/criticite-pr/state.sh            # PR ouvertes labellisées « autonome »
bash .claude/skills/criticite-pr/state.sh 14220 14217 # PR précises
```

Le script sort une ligne TSV par PR : numéro, statut, sha de tête, sha évalué, id du commentaire, niveau inscrit dans le marqueur, label `criticité:*` actuel, titre.

| Statut | Action |
|---|---|
| `nouvelle` | évaluer, poser le label, **créer** le commentaire |
| `à-réévaluer` | réévaluer sur le **diff complet** de la PR (pas le seul dernier push), **éditer** le commentaire |
| `à-jour` | rien ; à citer dans le récapitulatif |

## 2. Évaluer

Lis `gh pr view N --json title,body,files` et `gh pr diff N`. Pour lire un fichier dans sa version de la PR (code appelant, contexte) : `git fetch origin pull/N/head` puis `git show FETCH_HEAD:<chemin>`. Le niveau se fixe sur **le diff**. La description sert seulement à repérer les opérations à faire autour du merge.

Avec plus de 2 PR, lance un sous-agent `general-purpose` par PR à évaluer, en parallèle et dans un seul message. Les PR `à-jour` n'en reçoivent pas. Chaque sous-agent lit ce skill, l'applique à sa seule PR (sections 2 à 4) et rend 3 lignes : niveau, déclencheur, URL du commentaire. L'agent principal crée les labels manquants (section 4) **avant** de lancer les sous-agents, puis fait le récapitulatif.

### 🔴 haute
- **Authentification** : connexion, FranceConnect / ProConnect, mots de passe, sessions, 2FA, Devise, `config/initializers/{devise,omniauth,open_id_connect,otp,session_store,user_sessions}.rb`.
- **Autorisations** : qui voit quel dossier, `app/policies/`, les `before_action` d'accès dans les contrôleurs, les scopes d'accès, les tokens API, l'autorisation GraphQL (`authorized?`, `ready?`).
- **Données** :
  - migrations sur `dossiers`, `champs`, `users`, `active_storage_*`, `follows`, `individuals` ou `dossier_notifications` ;
  - `app/tasks/maintenance/` qui modifie des données ;
  - toute suppression (`destroy`, `delete_all`, `purge`, `discard`) de dossiers, de pièces jointes ou de comptes, ou tout élargissement des cas où une suppression est permise ;
  - rétention et expiration.
- **Fuite potentielle** : exports (CSV, PDF, ZIP, archives), URLs de pièces jointes, webhooks, emails qui contiennent des données de dossier.
- **Intégrité de ce que l'usager soumet** : IBAN, identité, préremplissage, tout ce qui permet à un tiers d'injecter des valeurs dans un dossier.
- **Infra et secrets** : `config/environments/production.rb`, credentials, gems d'auth ou de chiffrement.

### 🟠 moyenne
- Cycle de vie du dossier (transitions d'état), validations.
- Types de champs, conditions, répétitions, révisions de procédure.
- Jobs, notifications, contenu et destinataires des emails.
- API publique ou GraphQL qui change de comportement sans toucher aux droits (un champ exposé, une valeur désormais ignorée).
- Nouvelle dépendance ou montée de version majeure.
- Requêtes sur grosses tables, N+1 sur les pages à fort trafic.
- Changement qui demande une opération avant ou après le merge (activer un flag en prod, prévenir des admins).

### 🟢 faible
- CSS, i18n, wording, composants de vue sans logique.
- Refactoring couvert par des tests existants.
- Documentation, tests seuls, montées de version mineures.

### Règles de décision
1. **Le niveau le plus élevé l'emporte**, quelle que soit la taille du reste.
2. **Un doute entre deux niveaux fait prendre le niveau supérieur**, et le commentaire nomme ce doute.
3. **Un feature flag ne fait pas baisser le niveau** : on juge le code tel qu'il sera exécuté une fois le flag activé. Exception : la règle 4, quand le flag ne fait que garder un comportement qui existait déjà.
4. **Une PR qui retire ou restreint un comportement sensible descend d'un cran, jamais en dessous de 🟠.** On regarde l'effet : après le merge, plus personne n'obtient un comportement qu'il n'avait pas avant. Le code ajouté pour garder l'ancien comportement derrière un flag ne compte pas comme un ajout.
5. **Accessibilité 🟠** quand le diff touche, dans l'interface usager ou instructeur :
   - `aria-*`, `role`, les régions live ;
   - la gestion du focus ;
   - les `label`, `fieldset`, `legend` et les messages d'erreur d'un formulaire ;
   - un sélecteur CSS global (élément nu, attribut, override DSFR).

   Un changement purement visuel limité à un composant reste 🟢. Ce cas vaut aussi pour une PR qui corrige un défaut d'accessibilité.
6. **Au-delà de 400 lignes** (ajouts et suppressions, hors `spec/` et `*.test.ts`), une PR classée 🟢 passe 🟠.

## 3. Le commentaire

Le commentaire a exactement cette forme. Son rôle est de **justifier un niveau**, pas de faire la review : la review a sa propre étape.

```markdown
<!-- criticite-pr sha=<sha de tête complet> niveau=<haute|moyenne|faible> -->
### Criticité : 🔴 haute

<Une phrase : le déclencheur principal et la règle de la grille qu'il active.>

| Fichier | Domaine | Niveau |
|---|---|---|
| `app/models/user.rb` | suppression de comptes | 🔴 |
| `config/locales/…` | wording | 🟢 |

<Pour chaque règle 2 à 6 qui a servi : une phrase qui dit laquelle et pourquoi.>

**À vérifier par la relecture** : <1 à 3 points, chacun lié au domaine qui fixe le niveau. Omets la ligne s'il n'y en a pas.>

<sub>Relecture attendue : <rappel de la règle du niveau>. Évalué sur <sha court>.</sub>
```

- Le tableau ne garde qu'**une ligne par domaine**. Regroupe les fichiers d'un même domaine, et mets d'abord les lignes qui fixent le niveau. Un fichier qui relève de deux domaines apparaît sur les deux lignes.
- Un sha court fait 7 caractères.
- La colonne Niveau indique le niveau retenu après application des règles 2 à 6.
- Rappels de relecture :
  - 🔴 : « 2 relecteurs humains et un test manuel, review IA à titre indicatif » ;
  - 🟠 : « review IA puis 1 relecteur humain complet » ;
  - 🟢 : « review IA et lecture rapide, merge si CI verte ».
- **Réévaluation** : ajoute une dernière ligne `<sub>Historique : faible → moyenne le JJ/MM (<sha court>) : <raison en quelques mots></sub>`. Conserve les lignes d'historique précédentes. Si le niveau ne change pas, écris « niveau inchangé » dans cette ligne.

## 4. Poser

Au premier lancement, crée les labels s'ils manquent (`gh label list --search criticité`) :

```bash
gh label create "criticité:haute"   --color d73a4a --description "2 relecteurs humains, test manuel"
gh label create "criticité:moyenne" --color e99d42 --description "Review IA puis 1 relecteur humain complet"
gh label create "criticité:faible"  --color 0e8a16 --description "Review IA + lecture rapide, merge si CI verte"
```

Écris le commentaire dans un fichier du scratchpad, un fichier par PR.

```bash
# nouvelle
gh pr comment N --body-file <fichier>
# à-réévaluer : édition sur place
gh api -X PATCH repos/{owner}/{repo}/issues/comments/<id> -F body=@<fichier>
# label : retire seulement les labels criticité:* présents (colonne 7 de state.sh) et différents du nouveau, en deux commandes séparées
gh pr edit N --remove-label "criticité:<ancien>"   # seulement s'il y en a un
gh pr edit N --add-label "criticité:<niveau>"
```

Retirer un label absent fait échouer `gh pr edit` sans bruit, et l'ajout est perdu avec. Vérifie ensuite avec `gh pr view N --json labels`.

**Label changé à la main** : si le label actuel diffère du `niveau` du marqueur, un humain l'a modifié. Dans ce cas :
- ne baisse jamais ce label ;
- monte-le seulement si ta nouvelle évaluation est plus haute ;
- dans le commentaire, garde dans le marqueur et le titre le niveau que tu as évalué, et ajoute la ligne `<sub>Label fixé à la main à <niveau> : conservé.</sub>`.

## 5. Récapitulatif

Termine par un tableau `PR | Avant | Après | Déclencheur` qui couvre toutes les PR, celles `à-jour` comprises. Ajoute une ligne qui signale les PR 🔴.

Pour suivre les mises à jour en continu, l'utilisateur peut lancer `/loop 30m /criticite-pr`.
