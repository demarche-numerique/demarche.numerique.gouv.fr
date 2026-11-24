---
name: recette-pr
description: Prépare et guide la recette humaine d'une PR de demarche.numerique.gouv.fr — lit le diff, écrit un scénario de test concret, lance la PR en local sur une base dédiée, puis guide le relecteur pas à pas dans un navigateur Playwright (verdict par étape) et peut en tirer une vidéo. À utiliser quand l'utilisateur veut tester, recetter, valider à la main ou faire une démo d'une PR, ou lance /recette-pr <numéro>.
---

# Recette guidée d'une PR

La relecture de code dit si le code est correct ; la recette dit si **la fonctionnalité fait ce que la PR promet, vue par son persona**. L'agent fait tout ce qui n'a pas besoin d'un humain (comprendre le diff, préparer les données, lancer l'app, écrire et rejouer le scénario) ; l'humain garde le seul rôle qu'on ne peut pas lui retirer : **juger ce qu'il voit**.

Fichiers du skill (`.claude/skills/recette-pr/`) :

| Fichier | Rôle |
|---|---|
| `prepare.sh <N>` | worktree détaché `../review-pr-<N>` sur la tête de la PR, dépendances, base `tps_review_pr_<N>` rechargée depuis le schéma de la PR puis seedée (Oaken) |
| `serve.sh <N>` | Rails sur :3100 et Vite sur :3136, à côté du serveur de dev (3000/3036) qui reste intact |
| `recette.mjs <scenario> --mode auto\|guide\|video\|captures\|sonde` | joue le scénario (voir plus bas) ; la vidéo est commentée en voix off ; `sonde` affiche l'arbre d'accessibilité d'une page |
| `exemple-scenario.mjs` | scénario de référence (PR 14604) : à lire avant d'en écrire un |
| `outils.mjs` | outils passés aux étapes sous `outils` : `codeFrais(secret)` pour un code OTP |
| `cleanup.sh <N>` | arrête le serveur, supprime worktree et bases |

## 1. Comprendre la PR

```bash
gh pr view N --json title,body,headRefName,files,labels,state
gh pr diff N
```

Classe chaque changement : **visible** (un écran, un e-mail, un export, un message), **comportemental invisible** (validation, droits, job) ou **interne** (refacto, tests). Repère le persona, les pages touchées et les cas limites que le diff traite explicitement : verrouillages, droits, états du dossier, révision ancienne, données vides. Les specs système de la PR sont la meilleure source pour les locators et le parcours nominal.

**Si rien n'est visible ni vérifiable dans l'interface** (refacto pure, job, migration de données) : dis-le, propose ce qui se vérifie autrement (console Rails, e-mail dans `/letter_opener`) et arrête-toi là. Une recette n'a de valeur que si elle montre quelque chose.

## 2. Fiche de recette — validée par l'humain

Présente une fiche courte :

- **Persona** et compte utilisé ;
- **Données de départ** : ce que fournissent les seeds, ce qu'il faut créer en plus ;
- **Étapes** : 4 à 8, chacune avec une action et un **attendu observable** (« le bloc X disparaît », jamais « ça marche ») ;
- au moins **un cas limite ou de non-régression** tiré du diff, pas seulement le parcours nominal.

Demande validation avec `AskUserQuestion` (Lancer / Ajouter un cas / Modifier). C'est l'humain qui signe la recette : s'il ne reconnaît pas la feature dans la fiche, le reste ne sert à rien.

## 3. Lancer la PR en local

```bash
.claude/skills/recette-pr/prepare.sh N        # ~10 s si les dépendances sont celles de main
```

puis `serve.sh N` **en arrière-plan** (`run_in_background`), et attends que `curl -s -o /dev/null -w '%{http_code}' http://localhost:3100/users/sign_in` rende 200 (le premier rendu compile Vite).

- La base est **jetable et déterministe** : chaque `prepare.sh` la recrée depuis le `schema.rb` de la PR (`SKIP_TEST_DATABASE=1` : sans lui, Rails recréerait aussi la base de test du dépôt principal). Le code des migrations n'est donc pas exécuté : si la PR en contient, ce n'est pas la recette qui le valide. `--keep-db` conserve la base.
- `prepare.sh` n'arrête un serveur sur 3100/3136 que s'il tourne depuis le worktree de la PR ; sinon il s'arrête et demande.
- **Un réglage du `.env` peut désactiver ce que la PR teste.** Cherche dans le diff les constantes et drapeaux (`config/initializers/`, `ENV.fetch`) dont dépend la feature : le `.env` de dev désactive par exemple l'OTP super admin (`SUPER_ADMIN_OTP_ENABLED`). Passe la valeur voulue en variable d'environnement, qui prime sur le `.env`, à `serve.sh` **et** à `recette.mjs` (la préparation tourne avec son environnement).
- **Une autre recette tourne déjà** (3100/3136 pris par un autre `review-pr-*`) : ne l'arrête pas, décale les ports. `RECETTE_PORT=3200 RECETTE_VITE_PORT=3236` devant `prepare.sh` **et** `serve.sh`, puis `--base-url http://localhost:3200` pour `recette.mjs`.
- Comptes des seeds (mot de passe `users.default_password`, `db/seeds/setup.rb`) : `admin@exemple.fr` (administrateur + instructeur), `instructeur@exemple.fr`, `usager@exemple.fr`. Pour voir les démarches et dossiers seedés : `DB_DATABASE=tps_review_pr_N bin/rails runner 'puts Procedure.pluck(:id, :libelle, :aasm_state).map(&:inspect)'` dans le worktree.
- E-mails : `http://localhost:3100/letter_opener` pour ceux réellement envoyés. Pour **montrer** un mail, l'aperçu est plus simple : `/rails/mailers/<mailer>/<action>?part=text%2Fhtml` rend le HTML seul, sans le cadre de l'aperçu (les previews sont dans `spec/mailers/previews/`, avec des données fictives).
- `prepare.sh` refuse de mettre à jour un worktree modifié : ne force rien, demande.

## 4. Écrire le scénario

Dans `../review-pr-N/tmp/recette/scenario.mjs` (git-ignoré). Forme :

```js
export default {
  pr: 14604,
  titre: '…',                 // le titre de la PR
  contexte: '…',              // une phrase, affichée en ouverture de la vidéo
  narration: '…',             // optionnel : voix off d'ouverture, sinon `contexte`
  persona: 'admin@exemple.fr',// connexion par le formulaire usager ; omis = anonyme
  connexion: async ({ page, data, outils }) => {}, // optionnel : remplace `persona` (super admin, OTP…)
  preparation: `…ruby…`,      // optionnel, exécuté par bin/rails runner ; dernière ligne = JSON → `data`
  depart: (data) => `/admin/procedures/${data.vide}/champs`,
  etapes: [{
    titre, consigne,          // ce que l'humain lit
    narration,                // optionnel : voix off de l'étape en vidéo, sinon la consigne
    cible: ({ page }) => locator,       // ce qu'on manipule : surlignée avant l'action
    zone: ({ page }) => locator,        // optionnel : ce qu'on juge, amené à l'écran après l'action
    action: async ({ page, data, outils }) => {},  // « Le faire pour moi » en mode guide
    attendu: '…',             // ce que l'humain doit constater
    verifier: async ({ page }) => {}    // lève une erreur si l'attendu n'est pas là
  }]
};
```

Règles :
- **Chaque étape part d'un état stable.** En mode guide, l'humain clique dans le panneau entre deux étapes : un menu, une popover ou une modale ouverte à l'étape précédente est fermé. L'action rouvre ce dont elle a besoin (voir `ouvrirMenu` dans l'exemple).
- Locators par rôle, label et texte visibles (`getByRole`, `getByLabel`, `getByText`), scopés au bloc concerné. Les specs système de la PR donnent les libellés exacts, et leurs helpers (`add_column`, `add_filter`, `select_autocomplete`…) le parcours : lis leur implémentation dans `spec/support/` ou en bas de la spec, pas seulement leur appel.
- **Écris les actions d'après le DOM réel, pas en devinant.** Avant une action sur un widget, lance la sonde : `recette.mjs scenario.mjs --mode sonde [--page '/procedures/{procedure}'] [--clic 'Personnaliser le tableau' --clic 'Colonne à afficher']`. Elle joue la préparation, se connecte, ouvre la page (`{clé}` est pris dans `data`), clique les boutons ou liens nommés et affiche l'arbre d'accessibilité : rôles et noms exacts. Pièges déjà rencontrés : un « bouton » DSFR qui est un lien (`link "Personnaliser"`), un `Select` React Aria (un `button` qui ouvre une `listbox`, sans champ texte) dont la liste est **virtualisée** (une option hors de vue n'est pas dans le DOM : faire défiler la `listbox` jusqu'à elle), un bouton activé par un contrôleur Stimulus pas encore branché (attendre `networkidle` avant d'agir).
- **Cible et zone.** La cible est ce qu'on manipule ; quand l'attendu porte ailleurs (le tableau après « Personnaliser le tableau », une carte après une navigation), donne une `zone` : le runner l'amène à l'écran après l'action, y place le panneau et la cadre dans les captures. Sans elle, la vidéo affiche l'attendu sur un écran qui ne le montre pas.
- Données hors seeds → `preparation`, jamais des clics de mise en place dans les étapes : la recette montre la feature, pas le décor. Inspire-toi des seeds (`db/seeds/procedures.rb`, `db/seeds/dossiers.rb`) pour construire une démarche et ses dossiers. Le chemin d'une démarche n'est pas une colonne : `Procedure.find_with_path(path).first` pour la retrouver d'un run à l'autre.
- **`preparation` est rejouée à chaque lancement** (auto, guide, vidéo, captures, sonde) sur la même base : rends-la idempotente (`find_or_create_by!`, purge de ce qu'elle a créé et de ce que les étapes créent, comme une copie). Sinon chaque run empile des données et décale les compteurs que l'attendu cite.
- **Un attendu se déduit du code, pas de l'aperçu ni des traductions.** Lis le mailer, le composant ou la vue qui produit le texte, **et le contrôleur** (où mène la redirection, sous quelle condition un bloc s'affiche) avant d'écrire l'attendu : qui est listé, qui est exclu, au singulier ou au pluriel, sur quelle page. Une clé de traduction ne dit pas quand ni où elle s'affiche. Un attendu deviné fait échouer une étape sur un comportement correct, et c'est du temps perdu à trancher « bug du scénario ou bug de la PR ».
- **Personas qui ne passent pas par `/users/sign_in`** (super admin du manager…) : donne une fonction `connexion`. Avec un OTP, la préparation expose le secret (`otp_secret`) dans `data`, et `outils.codeFrais(secret)` calcule le code : il attend la fenêtre de 30 s suivante si le secret vient de servir, car un code consommé est refusé. Pour une étape jouée par un **second** compte (un validateur), l'action fait `page.context().clearCookies()` puis se connecte avec ce compte.
- Pas besoin de faire défiler la page dans les actions : le runner centre la cible (sans animation : le DSFR anime le défilement, et une capture partirait avant la fin) et recentre avant chaque capture. Le panneau passe du côté opposé à la cible, et revient à droite quand l'action a changé de page. Il est transparent aux clics, sauf ses boutons.
- `verifier` contrôle l'attendu, pas seulement l'absence d'erreur : chaque étape a le sien. **Tout texte cité entre guillemets dans l'attendu est vérifié mot pour mot** (`getByText`) : les libellés changent au fil des rebases, et un `isDisabled` seul laisse passer un message faux.
- Textes en français, du point de vue du persona, sans jargon de code.

## 5. Mettre au point en mode `auto`

```bash
cd ../review-pr-N && node <repo>/.claude/skills/recette-pr/recette.mjs tmp/recette/scenario.mjs --mode auto
```

Sans tête, joue actions et vérifications, écrit une capture par étape, `resultats.json` et `rapport.md` dans `tmp/recette/resultats-auto/`. Le rapport marque ces étapes 🤖 « vérifiées par le script » : seul le mode guide produit des ✅, qui sont des jugements humains. `RECETTE_DEBUG=1` affiche la console de la page.

Une préparation en échec affiche seulement l'erreur Ruby et les lignes du script en cause.

Itère jusqu'au vert, puis **regarde les captures** (Read) : une vérification qui passe sur un écran faux est pire qu'une vérification absente. Une capture qui montre le haut de la page au lieu de la cible est un défaut du runner, pas du scénario : corrige le runner plutôt que d'ajouter des défilements dans les actions.

Quand une étape échoue, tranche : **bug du scénario** (locator, timing) → corrige ; **bug de la PR** (l'attendu tiré de la description n'est pas là) → c'est un résultat de recette. Ne contourne pas, note-le pour l'humain avec la capture.

## 6. Recette guidée

Lance en arrière-plan (`run_in_background`) :

```bash
cd ../review-pr-N && node <repo>/.claude/skills/recette-pr/recette.mjs tmp/recette/scenario.mjs --mode guide
```

Un Chromium s'ouvre, connecté avec le persona. Le panneau en bas à droite donne l'étape, la consigne et l'attendu, surligne l'élément à manipuler et propose : **▶ Le faire pour moi**, **✅ Conforme**, **❌ Pas conforme** (champ de commentaire, Entrée pour valider), **▁** pour réduire le panneau. L'humain peut tout faire lui-même et explorer hors scénario avant de donner son verdict. « Le faire pour moi » sert **une fois par étape**, seulement si l'action n'a pas été faite à la main : sinon elle la défait (un toggle se recoche). Une action qui n'aboutit pas en 10 s affiche « Action impossible » et rend la main.

À la fin, le panneau affiche le bilan (« 5/6 conformes », les ❌ avec leur commentaire) et un bouton **Fermer la recette**. `resultats.json` et `rapport.md` sont réécrits après chaque verdict : fermer la fenêtre en cours de route garde ce qui a déjà été jugé.

Dis à l'humain qu'une fenêtre s'est ouverte et ce qu'on attend de lui, puis attends la notification de fin. Lis `tmp/recette/resultats-guide/resultats.json` et les captures, et résume : verdicts, commentaires des ❌, ce que tu en déduis pour la PR.

## 7. Vidéo (sur demande)

```bash
node <repo>/.claude/skills/recette-pr/recette.mjs tmp/recette/scenario.mjs --mode video [--rythme 1.5] [--muet] [--voix Thomas]
```

Sans tête, 1280×800, avec **le panneau du mode guide** en bas à droite (étape, consigne, attendu ; le statut « ✓ Vérifié par le script » remplace les boutons de verdict) et le surlignage de la cible, **commentée en voix off** (approche de `/demo-pr`, #14665). La voix dit la `narration` de l'étape (sinon sa consigne) pendant que l'action se joue, puis l'attendu une fois vérifié ; une étape dure au moins ~7 s et au moins le temps de ses phrases. Toutes les phrases sont synthétisées avant l'enregistrement. Une `narration` se dit à l'oral : courte, sans parenthèses ni libellés à rallonge.

Compte ~15 s par étape avec la voix : 9 étapes font ~2 min 30. Au-delà de 6 ou 7 étapes, propose de garder les cas limites pour le mode guide, ou d'écrire des `narration` plus courtes que les attendus.

La voix passe par `say` (macOS) et prend la première voix française installée (Thomas, Amélie…) ; `--voix` en choisit une autre (`say -v '?'`). Sans `say`, ou avec `--muet`, la vidéo sort muette, avec son panneau. ffmpeg est requis dans tous les cas (`brew install ffmpeg`).

L'attendu ne s'affiche et ne se dit qu'une fois `verifier` passé ; un échec s'affiche en rouge et termine la vidéo sur « Recette en échec à l'étape N » : ne livre jamais cette vidéo comme une démo : `tmp/recette/resultats-video/recette-pr-N.mp4` (~0,5 Mo muette, ~2 Mo par minute avec la voix). Vérifie 2 ou 3 images avec `ffmpeg -ss <t> -i … -frames:v 1 frame.png` avant de la proposer, **y compris entre deux étapes** : la vidéo garde les états intermédiaires qu'un `verifier` qui attend l'état final ne voit pas (un récapitulatif partiel affiché comme définitif pendant un job, par exemple). C'est un résultat de recette à remonter. `--rythme` ralentit ou accélère.

### Captures du panneau, pour la description d'une PR

```bash
node <repo>/.claude/skills/recette-pr/recette.mjs tmp/recette/scenario.mjs --mode captures
```

Sans tête, joue le scénario avec le panneau du mode guide et capture chaque étape deux fois : `NN-consigne.png` (consigne, cible surlignée) et `NN-attendu.png` (après l'action, attendu à juger). **Aucun verdict n'est cliqué** : ne simule jamais un ✅ pour produire une image, un bilan « 9/9 conformes » sans humain serait un faux.

GitHub n'a pas d'API pour joindre une vidéo à un commentaire : l'humain la glisse dans le commentaire de la PR. Même chose pour les captures : un gist public peut être refusé par les permissions de la session (fuite d'informations) ; dans ce cas, ne contourne pas, donne les chemins à l'humain. Propose le texte (`rapport.md` + verdicts) et ne publie qu'avec son accord (`gh pr comment N --body-file …`).

## 8. Nettoyer

Quand l'humain a fini : `.claude/skills/recette-pr/cleanup.sh N`. Garde le worktree s'il veut revenir sur la recette après de nouveaux commits : `prepare.sh N` le remet sur la nouvelle tête et recrée la base, le scénario reste dans `tmp/recette/`.
