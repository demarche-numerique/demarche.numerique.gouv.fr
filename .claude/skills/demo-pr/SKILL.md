---
name: demo-pr
description: Enregistre une démo vidéo commentée (voix off) d'une PR de demarche.numerique.gouv.fr, à partir d'un jeu de test en base de dev, pour la mettre dans la description de la PR ou la montrer en revue. À utiliser quand l'utilisateur demande une démo, une vidéo, un screencast ou un enregistrement d'écran d'une PR, ou lance /demo-pr <numéro>.
---

# Démo vidéo d'une PR

On écrit un **scénario** (une phrase de narration + des actions Playwright par scène), puis `record.mjs` produit `demo.mp4` : vidéo 1280×800, voix off `say`, élément commenté encadré en rouge.

Prérequis : macOS (`say`), `ffmpeg` (`brew install ffmpeg`), et dans le checkout principal `bun install` et `bunx playwright install chromium`.

`record.mjs` se lance **depuis le checkout principal**, par son chemin absolu (`$MAIN` ci-dessous) : la branche de la PR n'a pas forcément ce skill, et le script prend Playwright dans le `node_modules` voisin.

## 1. Comprendre la PR

`gh pr view N --json title,body,files` et `gh pr diff N`. Liste les comportements visibles qui changent : ce sont les scènes. Une démo dure 1 à 2 minutes : garde ce qui montre le changement, les cas limites vont dans un mode opératoire écrit. Une vidéo = un rôle : si la PR touche l'usager puis l'instructeur, fais deux vidéos.

## 2. Servir la branche de la PR

Le serveur de dev habituel (port 3000) tourne sur une autre branche : sers la PR depuis un worktree, sur le port 3001.

```bash
git fetch origin pull/N/head
git worktree add --detach ../demo-pr-N FETCH_HEAD
cp .env .envrc ../demo-pr-N/        # ignorés par git, et le boot échoue sans APP_HOST
cd ../demo-pr-N && bundle install && bun install
bin/rails db:migrate                # seulement si la PR a des migrations : elles touchent la base de dev partagée
VITE_RUBY_DEV_SERVER_CONNECTION_CHECK=true VITE_RUBY_PORT=3999 bin/rails server -p 3001   # en arrière-plan
```

Les deux variables `VITE_RUBY_*` font échouer la détection d'un serveur Vite (rien n'écoute sur 3999), donc le serveur compile les assets de ce worktree lui-même. Sans elles, un `tmp/vite-ruby.json` resté dans le worktree pointe les pages vers un Vite absent, et elles s'affichent sans JS ni CSS.

## 3. Préparer les données

Pars des seeds (`db/seeds/`), déjà en base de dev. Tous les comptes ont le mot de passe `this is a very complicated password !` :

| Rôle | Compte | Données utiles |
|---|---|---|
| usager | `usager@exemple.fr` | dossiers dans tous les états (`db/seeds/dossiers.rb`) |
| instructeur | `instructeur@exemple.fr` | rattaché à la démarche publiée `demarche-demo` |
| administrateur | `admin@exemple.fr` | démarches publiée, close, dépubliée et brouillon (`db/seeds/procedures.rb`) |
| expert | `expert@exemple.fr` | avis demandés (`db/seeds/avis.rb`) |

Ne crée que ce qui manque, avec un script `bin/rails runner` écrit dans le scratchpad (pas dans le dépôt) et lancé **dans le worktree de la PR**, pour avoir ses modèles. Prends `db/seeds/procedures.rb` pour modèle (`Procedure.new(...)`, `draft_revision.add_type_de_champ(...)`, `instructeur.assign_to_procedure(procedure)`).

- Rends-le **rejouable** : il supprime d'abord ce qu'il a créé au tour précédent (recherche par libellé) et affiche les ids. La démo modifie les données : relance-le avant chaque enregistrement.
- Si la connexion échoue avec le mot de passe ci-dessus (base pas seedée avec `db:seed:replant`), donne-en un au compte : `bin/rails runner 'User.find_by!(email: "admin@exemple.fr").update!(password: "…")'`.

## 4. Écrire le scénario

Copie `example-scenario.mjs` dans le scratchpad et adapte `login` (à omettre pour une page publique), `start` (chemin de la première page) et `scenes`. Chaque `run` reçoit `{ page, pause, focus, waitText }` :

| Helper | Effet |
|---|---|
| `focus(locator, ms)` | défile jusqu'à l'élément et l'encadre en rouge `ms` millisecondes |
| `waitText(text)` | attend un message transitoire (« Formulaire enregistré », flash) sans faire échouer la démo |
| `pause(ms)` | laisse le temps de voir |

Commence par une capture pleine page, pour trouver les sélecteurs. Elle compile aussi les assets, ce qui rend le premier chargement de l'enregistrement rapide :

```bash
node $MAIN/.claude/skills/demo-pr/record.mjs <scenario.mjs> <out_dir> --explore   # → <out_dir>/explore.png
```

Narration : des phrases courtes, au présent, qui disent ce qu'on voit (« Je coche…, le bloc disparaît »). Écris les nombres et sigles comme ils doivent être lus. Une scène dure au moins le temps de sa phrase : une action placée après une longue phrase arrive en retard, découpe plutôt en deux scènes.

## 5. Enregistrer et vérifier

```bash
node $MAIN/.claude/skills/demo-pr/record.mjs <scenario.mjs> <out_dir>
```

Le script affiche le chemin de `demo.mp4` et d'une planche `frames/sheet.png` (la dernière image de chaque scène). **Lis la planche** avant de livrer : chaque image doit montrer ce que dit sa phrase. Un sélecteur introuvable fait échouer le script avec un timeout Playwright qui nomme le locator.

Variables : `DEMO_VOICE` passe une voix à `say -v` (vérifie qu'elle est installée avec `say -v '?'`), sinon la voix système est utilisée ; `DEMO_BASE_URL` change le serveur visé.

## 6. Livrer

Donne le chemin de `demo.mp4` : l'utilisateur le glisse dans l'éditeur web de la description de la PR (10 Mo max). C'est le seul moyen d'avoir un lecteur vidéo dans une PR : `gh` ne sait pas téléverser de fichier, et un lien vers un gist télécharge la vidéo sans la lire.

## Ménage

1. Dans le worktree de la PR, défais ses migrations : `bin/rails db:migrate:down VERSION=<version>` pour chacune, de la plus récente à la plus ancienne.
2. Arrête le serveur du port 3001, puis `git worktree remove ../demo-pr-N`.
3. Le jeu de test reste en base de dev : signale-le.
