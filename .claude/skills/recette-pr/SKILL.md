---
name: recette-pr
description: Prépare et guide la recette humaine d'une PR de demarche.numerique.gouv.fr — lit le diff, écrit un scénario de test concret, lance la PR en local sur une base dédiée, puis guide le relecteur pas à pas dans un navigateur Playwright (verdict par critère d’acceptation), en tire une vidéo commentée et publie un commentaire de recette sur la PR. À utiliser quand l'utilisateur veut tester, recetter, valider à la main ou faire une démo d'une PR, ou lance /recette-pr <numéro>.
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
| `commentaire.mjs <scenario> <resultats.json> <url des images> [--video <url>] [--a-juger <fichier.md>]` | écrit le commentaire de recette à poster sur la PR (section 8) |
| `publier.sh <N> [--verdicts <resultats.json>] [--video <url>] [--a-juger <fichier.md>]` | publie les captures dans un gist, puis écrit le commentaire (section 8) |
| `outils.mjs` | outils passés aux étapes sous `outils` : `codeFrais(secret)` pour un code OTP |
| `cleanup.sh <N>` | arrête le serveur, supprime worktree et bases (section 9) |
| `voiceover.sh --check` / `voiceover.sh <scenario> [options]` | recette guidée au lecteur d'écran : vérifie la configuration du Mac, filme l'écran avec la voix de VoiceOver, relève les plages de parole (section 10) |

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
- **Critères d'acceptation** : 4 à 8, chacun avec une action et un **attendu observable** (« le bloc X disparaît », jamais « ça marche ») ; chaque critère devient une étape du scénario ;
- au moins **un cas limite ou de non-régression** tiré du diff, pas seulement le parcours nominal.

Demande validation avec `AskUserQuestion` (Lancer / Ajouter un cas / Modifier). C'est l'humain qui signe la recette : s'il ne reconnaît pas la feature dans la fiche, le reste ne sert à rien.

Note sa réponse dans le scénario, champ `fiche` : `'validée par <qui>'`, ou `'déléguée à l’agent'` s'il te laisse décider (« tout en auto »). Le commentaire de recette l'affiche : des critères signés par un humain et des critères choisis par l'agent ne pèsent pas pareil.

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
  fiche: 'validée par …',     // ou 'déléguée à l’agent' (section 2)
  persona: 'admin@exemple.fr',// connexion par le formulaire usager ; omis = anonyme
  connexion: async ({ page, data, outils }) => {}, // optionnel : connexion à la place du formulaire usager (super admin, OTP…) ; `persona` reste affiché
  env: { SUPER_ADMIN_OTP_ENABLED: 'enabled' },     // optionnel : variables à passer à serve.sh et recette.mjs
  prononciations: { ZIP: 'zip' },                   // optionnel : ce que la voix dit à la place d'un mot (section 7)
  preparation: `…ruby…`,      // optionnel, exécuté par bin/rails runner ; dernière ligne = JSON → `data`
  donnees: '…',               // optionnel : l'état de départ en prose, affiché dans l'onglet « Données » du panneau
  script: () => {},           // optionnel : script injecté dans chaque page (addInitScript), pour rendre visible ce qui ne l'est pas
  depart: (data) => `/admin/procedures/${data.vide}/champs`,
  etapes: [{                  // une étape par critère d'acceptation
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

### Règles d'écriture

- **Chaque étape part d'un état stable.** En mode guide, l'humain clique dans le panneau entre deux étapes : un menu, une popover ou une modale ouverte à l'étape précédente est fermé. L'action rouvre ce dont elle a besoin (voir `ouvrirMenu` dans l'exemple).
- **Écris les actions d'après le DOM réel, pas en devinant.** Locators par rôle, label et texte visibles (`getByRole`, `getByLabel`, `getByText`), scopés au bloc concerné. Les specs système de la PR donnent les libellés exacts, et leurs helpers (`add_column`, `add_filter`, `select_autocomplete`…) le parcours : lis leur implémentation dans `spec/support/` ou en bas de la spec, pas seulement leur appel. Avant une action sur un widget, lance la sonde : `recette.mjs scenario.mjs --mode sonde [--page '/procedures/{procedure}'] [--clic 'Personnaliser le tableau' --clic 'Colonne à afficher']`. Elle joue la préparation, se connecte, ouvre la page (`{clé}` est pris dans `data`), clique les boutons ou liens nommés et affiche l'arbre d'accessibilité : rôles et noms exacts.
- **Un attendu se déduit du code, pas de l'aperçu ni des traductions.** Lis le mailer, le composant ou la vue qui produit le texte, **et le contrôleur** (où mène la redirection, sous quelle condition un bloc s'affiche) avant d'écrire l'attendu : qui est listé, qui est exclu, au singulier ou au pluriel, sur quelle page. Une clé de traduction ne dit pas quand ni où elle s'affiche. Un attendu deviné fait échouer une étape sur un comportement correct, et c'est du temps perdu à trancher « bug du scénario ou bug de la PR ».
- **`verifier` contrôle l'attendu**, pas seulement l'absence d'erreur : chaque étape a le sien. **Tout texte cité entre guillemets dans l'attendu est vérifié mot pour mot** (`getByText`) : les libellés changent au fil des rebases, et un `isDisabled` seul laisse passer un message faux.
- **Cible et zone.** La cible est ce qu'on manipule ; quand l'attendu porte ailleurs (le tableau après « Personnaliser le tableau », une carte après une navigation, un réglage plus bas dans le bloc), donne une `zone` : le runner l'amène à l'écran après l'action, y place le panneau et la cadre dans les captures. Sans elle, le relecteur doit faire défiler, et la vidéo affiche l'attendu sur un écran qui ne le montre pas. Pas besoin de défilement dans les actions : le runner centre la cible et la zone, sans animation, et le panneau se place du côté opposé, transparent aux clics sauf ses boutons.
- **Données hors seeds → `preparation`**, jamais des clics de mise en place dans les étapes : la recette montre la feature, pas le décor. Inspire-toi des seeds (`db/seeds/procedures.rb`, `db/seeds/dossiers.rb`) pour construire une démarche et ses dossiers. **Elle est rejouée à chaque lancement** (auto, guide, vidéo, captures, sonde) sur la même base : rends-la idempotente (`find_or_create_by!`, purge de ce qu'elle a créé et de ce que les étapes créent, comme une copie). Sinon chaque run empile des données et décale les compteurs que l'attendu cite.
- **`donnees` dit au relecteur d'où vient l'état qu'il voit** : ce que fournissent les seeds, ce que la préparation ajoute, et pourquoi (un champ limité à une démarche où le persona n'a rien, par exemple). L'onglet « Données » du panneau l'affiche, avec les valeurs de `data` et le Ruby de la préparation.
- **Ce qui ne se voit pas à l'écran** (une région `aria-live` en `fr-sr-only`, un attribut) : rends-le visible avec un `script`, par exemple un bandeau qui recopie la région, marqué comme outil de recette et en `aria-hidden`. Il passe par le contexte de la recette : une `connexion` ne peut pas l'installer, elle tourne dans un contexte séparé dont seuls les cookies sont gardés. Le `verifier` lit l'élément d'origine, jamais le bandeau.
- **Personas qui ne passent pas par `/users/sign_in`** (super admin du manager…) : donne une fonction `connexion`. Avec un OTP, la préparation expose le secret (`otp_secret`) dans `data`, et `outils.codeFrais(secret)` calcule le code. Pour une étape jouée par un **second** compte (un validateur), l'action fait `page.context().clearCookies()` puis se connecte avec ce compte.
- Textes en français, du point de vue du persona, sans jargon de code.

### Pièges déjà rencontrés

- **DSFR** : un « bouton » peut être un lien (`link "Personnaliser"`) ; le défilement est animé (`scroll-behavior: smooth`), d'où le défilement instantané du runner.
- **React Aria** : un `Select` est un `button` qui ouvre une `listbox`, sans champ texte, et sa liste est **virtualisée** : une option hors de vue n'est pas dans le DOM, fais défiler la `listbox` jusqu'à elle.
- **Stimulus et React chargés tard** : un bouton activé par un contrôleur pas encore branché reste grisé, et un composant React qui porte une valeur du formulaire (une démarche présélectionnée, par exemple) ne l'ajoute qu'une fois monté. Soumettre avant envoie un formulaire incomplet, sans erreur visible tout de suite : le mode `auto` échoue alors au hasard, les modes plus lents passent. Attends `networkidle` et la valeur visible avant de soumettre.
- **OTP** : un code déjà consommé dans la fenêtre de 30 s est refusé ; `outils.codeFrais` attend la fenêtre suivante.
- **`.env` de dev** : il peut désactiver la feature testée (section 3) ; déclare la variable dans `env`.
- **Le chemin d'une démarche** n'est pas une colonne : `Procedure.find_with_path(path).first` pour la retrouver d'un run à l'autre.

## 5. Mettre au point en mode `auto`

```bash
cd ../review-pr-N && node <repo>/.claude/skills/recette-pr/recette.mjs tmp/recette/scenario.mjs --mode auto
```

Sans tête, joue actions et vérifications, écrit une capture par étape, `resultats.json` et `rapport.md` dans `tmp/recette/resultats-auto/`. Le rapport marque ces étapes 🤖 « vérifiées par le script » : seul le mode guide produit des ✅, qui sont des jugements humains. `RECETTE_DEBUG=1` affiche la console de la page.

Une préparation en échec affiche seulement l'erreur Ruby et les lignes du script en cause.

**Chaque lancement vide son dossier de sortie** (`resultats-<mode>/`). Pour mettre au point le runner ou le panneau après une recette humaine, passe `--out` vers un dossier jetable : sinon les verdicts ✅ et les captures de l'humain sont écrasés, et lui seul peut les refaire.

Itère jusqu'au vert, puis **regarde les captures** (Read) : une vérification qui passe sur un écran faux est pire qu'une vérification absente. Une capture qui montre le haut de la page au lieu de la cible est un défaut du runner, pas du scénario : corrige le runner plutôt que d'ajouter des défilements dans les actions.

Le runner s'arrête au premier échec : les étapes suivantes partent d'un état qui n'est plus garanti. Pour **comparer deux versions** (avant et après un correctif), `--continuer` joue toutes les étapes et donne le bilan complet ; chaque étape doit alors repartir d'un état qu'elle installe elle-même.

Quand une étape échoue, tranche : **bug du scénario** (locator, timing) → corrige ; **bug de la PR** (l'attendu tiré de la description n'est pas là) → c'est un résultat de recette. Ne contourne pas, note-le pour l'humain avec la capture.

## 6. Recette guidée

Lance en arrière-plan (`run_in_background`) :

```bash
cd ../review-pr-N && node <repo>/.claude/skills/recette-pr/recette.mjs tmp/recette/scenario.mjs --mode guide
```

Un Chromium s'ouvre, connecté avec le persona. Le panneau en bas à droite donne le critère, sa consigne et son attendu (onglet **📋 Consigne**, rouvert à chaque critère et après « Le faire pour moi ») ; quand le scénario a une `preparation` ou des `donnees`, l'onglet **🧪 Données** élargit le panneau et montre l'état de départ, les valeurs de `data` et le Ruby exécuté. Le panneau surligne l'élément à manipuler et propose : **▶ Le faire pour moi**, **✅ Conforme**, **❌ Pas conforme** (champ de commentaire, Entrée pour valider), **▁** pour réduire le panneau. L'humain peut tout faire lui-même et explorer hors scénario avant de donner son verdict. « Le faire pour moi » sert **une fois par étape**, seulement si l'action n'a pas été faite à la main : sinon elle la défait (un toggle se recoche). Une action qui n'aboutit pas en 10 s affiche « Action impossible » et rend la main.

À la fin, le panneau affiche le bilan (« 5/6 conformes », les ❌ avec leur commentaire) et un bouton **Fermer la recette**. `resultats.json` et `rapport.md` sont réécrits après chaque verdict : fermer la fenêtre en cours de route garde ce qui a déjà été jugé.

`--enregistrer` filme la recette guidée en mp4 (`recette-pr-N-guide.mp4`) : la vidéo montre ce que vit le relecteur, panneau, « Le faire pour moi », verdicts et commentaires, à côté de la vidéo du mode `video` où le script joue seul. Une voix off (sauf `--muet`) explique le panneau d'aide à la revue, puis pour chaque critère ce qu'on cherche à valider et le verdict ; l'heure de fin de la phrase en cours est publiée dans l'état du panneau (`voixJusqua`) pour qu'un relecteur de démonstration attende la fin avant d'agir. Dans les deux vidéos, un faux curseur suit la souris et un halo orange marque chaque clic : Playwright filme la page, pas l'écran, donc les options d'accessibilité de macOS n'y apparaissent pas. Quand un agent tient le rôle du relecteur (démonstration, pilotage par CDP avec `RECETTE_CDP_PORT`), lance avec `--juge agent` : le rapport le dit au lieu de compter des verdicts humains.

Dis à l'humain qu'une fenêtre s'est ouverte et ce qu'on attend de lui, puis attends la notification de fin. Lis `tmp/recette/resultats-guide/resultats.json` et les captures, et résume : verdicts, commentaires des ❌, ce que tu en déduis pour la PR.

## 7. Vidéo (sur demande)

```bash
node <repo>/.claude/skills/recette-pr/recette.mjs tmp/recette/scenario.mjs --mode video [--rythme 1.5] [--muet]
```

Sans tête, 1280×800, avec **le panneau du mode guide** en bas à droite (étape, consigne, attendu ; le statut « ✓ Vérifié par le script » remplace les boutons de verdict) et le surlignage de la cible, **commentée en voix off** (approche de `/demo-pr`, #14665). La voix dit la `narration` de l'étape (sinon sa consigne) pendant que l'action se joue, puis l'attendu une fois vérifié ; une étape dure au moins ~7 s et au moins le temps de ses phrases. Toutes les phrases sont synthétisées avant l'enregistrement. Une `narration` se dit à l'oral : courte, sans parenthèses ni libellés à rallonge.

Compte ~15 s par étape avec la voix : 9 étapes font ~2 min 30. Au-delà de 6 ou 7 étapes, propose de garder les cas limites pour le mode guide, ou d'écrire des `narration` plus courtes que les attendus.

La voix off passe par **`say`** quand il a une voix française Améliorée ou Premium : sur macOS, ce sont les plus naturelles (la meilleure qualité d'abord, puis Aurélie, Audrey, Marie, Thomas). Une telle voix s'installe dans Réglages Système > Accessibilité > Lire et énoncer > ⓘ à côté de « Voix système » ; vérifie avec `say -v '?'` qu'elle est visible de `say` (les voix Siri ne le sont pas).

Sinon, sous Linux ou sur un Mac sans bonne voix, elle passe par **Piper**, un moteur de synthèse libre et local. Installation, une fois :

```bash
uv tool install --python 3.12 piper-tts     # ou pipx install piper-tts
~/.local/share/uv/tools/piper-tts/bin/python -m piper.download_voices --download-dir ~/.local/share/piper fr_FR-siwis-medium
```

Le runner prend la première voix Piper installée parmi `fr_FR-siwis-medium`, `fr_FR-upmc-medium` et `fr_FR-tom-medium`, dans `~/.local/share/piper` (ou `RECETTE_PIPER_MODELS`). En dernier recours, une voix `say` compacte, au rendu robotique, avec un avertissement ; sans l'un ni l'autre, ou avec `--muet`, la vidéo sort muette, avec son panneau. `--voix` impose une voix : un nom `say` (`'Aurélie (Enhanced)'`), un modèle Piper, `modèle:locuteur` (par exemple `fr_FR-upmc-medium:1`) ou un chemin vers un `.onnx`. ffmpeg est requis dans tous les cas (`brew install ffmpeg`, ou le paquet de la distribution).

**Prononciation.** Avec Piper, le dictionnaire d'espeak-ng développe certaines abréviations : « PR » y est « professeur ». Le runner épelle donc tout acronyme (deux majuscules ou plus) en phonèmes, passés à Piper entre `[[ … ]]`, sauf ceux qui se disent comme un mot (SIRET, SIREN, IBAN, RIB). `say` lit les sigles lui-même et ne comprend pas ces phonèmes : avec lui, seules les prononciations en texte s'appliquent. Le texte affiché ne change pas : seule la voix est concernée. Un mot propre à la PR qui sonne mal se corrige dans le champ `prononciations` du scénario, en texte (`{ ZIP: 'zip' }`, pour un sigle qui se dit comme un mot) ou en phonèmes pour Piper (`{ Mathieu: '[[ matjˈø ]]' }`). Pour trouver les phonèmes d'un mot, fais phonétiser à Piper une graphie qui sonne juste :

```bash
~/.local/share/uv/tools/piper-tts/bin/python -c "from piper import PiperVoice; v = PiperVoice.load('$HOME/.local/share/piper/fr_FR-siwis-medium.onnx'); print(''.join(v.phonemize('pé erre')[0]))"
```

L'attendu ne s'affiche et ne se dit qu'une fois `verifier` passé ; un échec s'affiche en rouge et termine la vidéo sur « Recette en échec à l'étape N » : ne livre jamais cette vidéo comme une démo : `tmp/recette/resultats-video/recette-pr-N.mp4` (~0,5 Mo muette, ~2 Mo par minute avec la voix). Vérifie 2 ou 3 images avec `ffmpeg -ss <t> -i … -frames:v 1 frame.png` avant de la proposer, **y compris entre deux étapes** : la vidéo garde les états intermédiaires qu'un `verifier` qui attend l'état final ne voit pas (un récapitulatif partiel affiché comme définitif pendant un job, par exemple). C'est un résultat de recette à remonter. `--rythme` ralentit ou accélère.

## 8. Publier sur la PR

Ce que reçoit le relecteur de la PR : un commentaire de recette, avec les captures et la vidéo.

1. **Captures** : `recette.mjs scenario.mjs --mode captures` joue le scénario avec le panneau du mode guide et capture chaque critère deux fois, `NN-consigne.png` (consigne, cible surlignée) et `NN-attendu.png` (après l'action, attendu à juger). **Aucun verdict n'est cliqué** : ne simule jamais un ✅ pour produire une image, un bilan « 9/9 conformes » sans humain serait un faux.
2. **Gist et commentaire** : `publier.sh N` crée un gist public avec les captures, puis lance `commentaire.mjs` pour écrire `tmp/recette/commentaire.md`. Le gist est une publication : la session de l'agent peut la refuser (fuite d'informations). Dans ce cas, ne contourne pas : donne la commande à l'humain, qui la lance avec `!`. Options :
   - `--verdicts tmp/recette/resultats-guide/resultats.json` pour publier les verdicts de la recette guidée plutôt que ceux du script ;
   - `--video <url user-attachments>` pour garder une vidéo déjà glissée dans GitHub en régénérant le commentaire ;
   - `--a-juger <fichier.md>` pour les constats que l'humain doit trancher.
3. **Poster** : propose le texte, et ne publie qu'avec l'accord de l'humain (`gh pr comment N --body-file tmp/recette/commentaire.md`).
4. **Vidéo** : GitHub n'a pas d'API pour joindre une vidéo. L'humain la glisse dans le commentaire, à la place de « _Vidéo à glisser ici_ ».

Le commentaire se lit sans rien déplier, puis se creuse à la demande. Sous le titre « Recette de #N » :
- **Contexte** : une phrase, la situation suivie du persona ;
- **À juger**, avec `--a-juger` : les constats de la recette (écart de comportement, état intermédiaire vu dans la vidéo…) ;
- **Validation visuelle** : la vidéo ;
- **Critères d'acceptation**, le bilan dans le titre selon qui a jugé (« vérifiés par le script 🤖 », « jugés conformes par un humain ✅ », « jugés conformes par un agent 🤖 ») et la fiche, validée ou déléguée. Un accordéon `<details>` par critère : le bouton ne porte que le verdict, le numéro et le titre ; déplié, il donne la consigne, l'attendu et les deux captures en pleine largeur ;
- **Rejouer en local** : un prompt à copier dans Claude Code, autonome car il embarque le scénario joué (et ses variables `env`).

## 9. Nettoyer

Quand l'humain a fini : `.claude/skills/recette-pr/cleanup.sh N`. Garde le worktree s'il veut revenir sur la recette après de nouveaux commits : `prepare.sh N` le remet sur la nouvelle tête et recrée la base, le scénario reste dans `tmp/recette/`.

## 10. Recette au lecteur d'écran (VoiceOver, macOS)

Quand la PR touche à ce qu'entend un lecteur d'écran (région `aria-live`, `aria-describedby`, ordre de lecture), le bandeau d'un `script` (section 4) montre ce qui est **envoyé** ; seul VoiceOver dit ce qui est **prononcé**. Un nœud live inséré avec son contenu (un `turbo_stream.replace`, par exemple) n'est souvent pas lu : la recette au lecteur d'écran le révèle, la vérification du DOM jamais.

### Configuration du Mac, une fois

`voiceover.sh --check` vérifie tout ce qui se vérifie en ligne de commande et dit quoi faire pour le reste.

1. **Pilote de bouclage audio** : `brew install blackhole-2ch` (redémarrage du Mac demandé).
2. **Appareil à sorties multiples** : Configuration audio et MIDI > **+** > « Créer un appareil à sorties multiples » ; cocher le casque ou les haut-parleurs (appareil principal) **et** BlackHole 2ch, « Correction de la dérive » sur BlackHole. On entend, et BlackHole reçoit la même chose.
3. **Sortie de VoiceOver** : Utilitaire VoiceOver > **Son** > Périphérique de sortie = l'appareil à sorties multiples. Seule la voix de VoiceOver part dans l'enregistrement, pas les notifications ; la sortie du Mac ne change pas. La barre latérale de l'Utilitaire est masquée quand la fenêtre est étroite : l'élargir ou ⌃⌘S.
4. **Sous-titres** : Utilitaire VoiceOver > **Effets visuels** > afficher le panneau des sous-titres. Le texte de chaque phrase apparaît à l'écran : c'est ce que l'agent lit dans la vidéo.
5. **Enregistrement de l'écran** : Réglages Système > Confidentialité et sécurité > Enregistrement de l'écran et audio du système > cocher le terminal, puis le **quitter (⌘Q) et le rouvrir**. La session Claude Code s'arrête : donner à l'humain la commande `claude --resume <id de session>`, l'id est dans le chemin du scratchpad ; les serveurs lancés en arrière-plan (`serve.sh`) sont à relancer.
6. Optionnel : Utilitaire VoiceOver > Général > « Permettre à AppleScript de contrôler VoiceOver » ; `tell application "VoiceOver" to content of last phrase` rend la dernière phrase dite, base d'une vérification automatique (non outillée ici).

Pièges : `screencapture` qui échoue avec « could not create image from display » = autorisation manquante ; ffmpeg avfoundation refuse `yuv420p` en entrée (`-pixel_format nv12`) ; la locale française fait lire « 113.7 » comme 113 à `awk` (`LC_ALL=C`).

### Jouer la recette

```bash
cd ../review-pr-N && <repo>/.claude/skills/recette-pr/voiceover.sh tmp/recette/scenario.mjs --base-url http://localhost:3100
```

Lance-le en arrière-plan. Dis à l'humain : ⌘F5 pour activer VoiceOver ; pour chaque critère, saisir puis **Tab** (l'enregistrement automatique part à la sortie du champ) et écouter ; verdicts à la souris ; tout faire dans la fenêtre Chromium (tout l'écran est filmé) ; **fermer la fenêtre de recette** à la fin, ce qui arrête et finalise la vidéo. Sortie : `tmp/recette/recette-voiceover.mp4`, `tmp/recette/parole.txt` (plages où VoiceOver parle), verdicts dans `tmp/recette/resultats-voiceover/`.

### Lire ce que VoiceOver a dit

Les sous-titres sont dans la vidéo : l'agent les lit, l'humain n'a rien à retranscrire.

1. `parole.txt` donne les plages à regarder ; aucune parole = VoiceOver jamais activé, ou sa sortie ne passe pas par BlackHole.
2. Une planche toutes les 3 s pour suivre les critères : `ffmpeg -ss <début> -i recette-voiceover.mp4 -t <durée> -vf "fps=1/3,scale=640:-1,tile=3x6" -frames:v 1 planche.png`.
3. Puis le panneau des sous-titres seul, 2 images par seconde, sur la plage d'un critère : repère sa position sur une image, puis `-vf "fps=2,crop=<l>:<h>:<x>:<y>,tile=4x10"`. Une annonce polie ne dure qu'une ou deux secondes : une planche à 1/3 s la rate.
4. Compare à l'attendu, mot pour mot, et regarde **ce qui la suit** : une relecture du champ juste après l'annonce (le champ focalisé recréé par un `replace`) peut la couper.
5. Vérifie que l'humain a joué l'action décrite (le bon champ, la bonne valeur) : un ✅ sur une étape jouée ailleurs ne prouve rien, signale-le.

### Publier la vidéo

Coupe ce qui précède la première parole (`ffmpeg -ss <début - 2 s> -i … -c:v libx264 -crf 26 -c:a aac -b:a 96k -movflags +faststart court.mp4`). GitHub n'a pas d'API pour joindre une vidéo : publie-la dans un gist (comme `publier.sh` : `gh gist create` d'un README, clone, ajout du mp4, push), **secret** par défaut, car tout l'écran est filmé. Le gist la sert en `application/octet-stream` : le lien la télécharge. Pour qu'elle se lise dans le commentaire de recette, l'humain la glisse dans GitHub.

