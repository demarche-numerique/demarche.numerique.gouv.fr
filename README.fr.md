# demarche.numerique.gouv.fr

## Contexte

[demarche.numerique.gouv.fr](https://demarche.numerique.gouv.fr) est un site web conçu afin de répondre au besoin urgent de l’État d’appliquer la directive sur le 100 % dématérialisation pour les démarches administratives.

## Comment contribuer ?

demarche.numerique.gouv.fr est un [logiciel libre](https://fr.wikipedia.org/wiki/Logiciel_libre) sous licence AGPL.

Le système de design de l'État (`@gouvfr/dsfr`) et les éléments de la marque de l'État présents dans ce dépôt font exception à l'AGPL. Jusqu'à la version 1.14.3, le DSFR était publié sous licence MIT et ses conditions d'utilisation autorisaient expressément les tiers hors administration à en réutiliser le code source. Ce n'est plus le cas : depuis la 1.15.1, le code est sous [licence Etalab 2.0](https://github.com/GouvernementFR/dsfr/blob/main/LICENSE.md), qui précise que « le DSFR ne doit pas être utilisé par des entités extérieures à l'administration, et limite sa réplicabilité en dehors d'un nom de domaine en `.gouv.fr` », et son usage est encadré par des [modalités d'utilisation](https://github.com/GouvernementFR/dsfr/blob/main/doc/legal/cgu.md) que vous acceptez du seul fait de les télécharger et de les utiliser, et dont nous ne pouvons pas vous dispenser.

Concrètement : nous ne versionnons pas de fichier `.dsfr.yml`, pour que la décision d'accepter ces modalités reste la vôtre, et l'installation des dépendances JavaScript vous la posera explicitement (voir [`doc/DEPLOYMENT.md`](doc/DEPLOYMENT.md)). Si votre déploiement n'y est pas fondé, retirez ou remplacez ces ressources — y compris les polices Marianne embarquées dans `app/assets/fonts/`, `public/fonts/` et `lib/prawn/fonts/marianne/`, et les logos Marianne de `app/assets/images/`, qui relèvent en outre de [modalités distinctes](https://www.info.gouv.fr/marque-de-letat/la-typographie).

Vous souhaitez y apporter des changements ou des améliorations ? Lisez notre [guide de contribution](CONTRIBUTING.md).

## Installation pour le développement

### Dépendances techniques

#### Tous environnements

- postgresql (version >= 15)
- libvips-dev (version >= 8.13, traitement d’images et génération de filigranes)
- gsfonts (polices pour le rendu du texte des filigranes)

Les jobs asynchrones sont traités par `sidekiq`. Pour le faire tourner, vous aurez besoin de :

- redis

- lightgallery : une license a été souscrite pour soutenir le projet, mais elle n’est pas obligatoire si la librairie est utilisée dans le cadre d’une application open source.

#### Développement

- rbenv : voir https://github.com/rbenv/rbenv-installer#rbenv-installer--doctor-scripts
- Bun : voir https://bun.sh/docs/installation

#### Tests

Les tests systèmes s’exécutent avec Playwright (Chromium par défaut). Le navigateur est installé par `bin/setup` (ou `bun playwright install chromium`). Définissez `PLAYWRIGHT_BROWSER=firefox` ou `PLAYWRIGHT_BROWSER=webkit` pour les exécuter dans un autre navigateur.

### Création des rôles de la base de données

Les informations nécessaire à l’initialisation de la base doivent être pré-configurées à la main grâce à la procédure suivante :

    su - postgres
    psql
    > create user tps_development with password 'tps_development' superuser;
    > create user tps_test with password 'tps_test' superuser;
    > \q

### Initialisation de l’environnement de développement

Sous Ubuntu, certains packages doivent être installés au préalable :

    sudo apt-get install libcurl3 libcurl3-gnutls libcurl4-openssl-dev libcurl4-gnutls-dev zlib1g-dev

Afin d’initialiser l’environnement de développement, exécutez la commande suivante :

    bin/setup

Le premier passage s’arrête avant l’installation des dépendances JavaScript : `@gouvfr/dsfr` refuse de s’installer tant que ses [modalités d’utilisation](https://github.com/GouvernementFR/dsfr/blob/main/doc/legal/cgu.md) n’ont pas été acceptées. `bin/setup` vient de créer votre `.env` à partir de `config/env.example` : lisez ces modalités, décommentez `DSFR_ACCEPT_LICENSE` dans ce fichier si vous êtes fondé à utiliser le DSFR, puis relancez `bin/setup`. Votre `.env` n’est jamais commité — nous ne versionnons délibérément aucun fichier d’acceptation, pour que la décision soit prise une fois par machine plutôt qu’héritée de ce dépôt.

### Lancement de l’application

On lance le serveur d’application ainsi :

    bin/dev

L’application tourne alors à l’adresse `http://localhost:3000` avec en parallèle le bundler vitejs.

Les jobs asynchrones s’exécutent par défaut dans le process web (adapter `async`). Pour passer par sidekiq,
poser `RAILS_QUEUE_ADAPTER=sidekiq` dans votre `.env` et lancer `bundle exec sidekiq` à côté de `bin/dev`.

### Utilisateurs de test

En local, un utilisateur de test est créé automatiquement, avec les identifiants `test@exemple.fr`/`this is a very complicated password !`. (voir [db/seeds.rb](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/blob/dev/db/seeds.rb))

### Programmation des tâches récurrentes

    rails jobs:schedule

### Voir les emails envoyés en local

Ouvrez la page [http://localhost:3000/letter_opener](http://localhost:3000/letter_opener).

### Mise à jour de l’application

Pour mettre à jour votre environnement de développement, installer les nouvelles dépendances et faire jouer les migrations, exécutez :

    bin/update

### Exécution des tests (RSpec)

Les tests ont besoin de leur propre base de données et certains d’entre eux s’exécutent dans un navigateur via Playwright. N’oubliez pas de créer la base de test et d’installer le navigateur Playwright (`bun playwright install chromium`) pour exécuter tous les tests.

Pour exécuter les tests de l’application, plusieurs possibilités :

- Lancer tous les tests

        bin/rake spec
        bin/rspec

- Lancer un test en particulier

        bin/rake spec SPEC=file_path/file_name_spec.rb:line_number
        bin/rspec file_path/file_name_spec.rb:line_number

- Lancer tous les tests d’un fichier

        bin/rake spec SPEC=file_path/file_name_spec.rb
        bin/rspec file_path/file_name_spec.rb

- Relancer uniquement les tests qui ont échoué précédemment

        bin/rspec --only-failures

- Lancer un ou des tests systèmes avec un browser

        NO_HEADLESS=1 bin/rspec spec/system

- Afficher les logs js issus de la console du navigateur `console.error('coucou')`

        LOG_WEB_CONSOLE=1 bin/rspec spec/system

- Augmenter la latence réseau lors de tests end2end pour déceler des bugs récalcitrants (Chromium uniquement)

        MAKE_IT_SLOW=1 bin/rspec spec/system

### Ajout de taches à exécuter au déploiement

        rails generate maintenance_tasks:task task_name

### Linting

Le projet utilise plusieurs linters pour vérifier la lisibilité et la qualité du code.

- Faire tourner tous les linters : `bin/rake lint`
- Vérifier l’état des traductions : `bundle exec i18n-tasks health`
- [AccessLint](http://accesslint.com/) tourne automatiquement sur les PRs

### Régénérer les binstubs

    bundle binstub railties --force
    bin/rake rails:update:bin

## Déploiement

Voir les notes de déploiement dans [DEPLOYMENT.md](doc/DEPLOYMENT.md)

> [!IMPORTANT]
> L'application doit être déployée derrière un reverse proxy (par exemple nginx, HAProxy) qui réécrit le header `X-Forwarded-For` avec l'IP réelle du client.
>
> Plusieurs mécanismes de sécurité s'appuient sur `request.remote_ip` pour identifier le client :
>
> - le rate limiting (`Rack::Attack`)
> - le gate « réseau de confiance » (instructeurs dispensés de 2FA quand ils viennent d'une IP trusted)
> - la restriction d'IP pour les jetons d'API (`whitelisted_ip_*` sur les API tokens)
>
> Sans un proxy qui assainit `X-Forwarded-For`, un client peut spoofer le header et contourner ces protections.

## Tâches courantes

### Tâches de gestion des comptes super-admin

Des tâches de gestion des comptes super-admin sont prévues dans le namespace `superadmin`.
Pour les lister : `bin/rake -D superadmin:`.

### Tâches d’aide au support

Des tâches d’aide au support sont prévues dans le namespace `support`.
Pour les lister : `bin/rake -D support:`.

## Performance

[![View performance data on Skylight](https://badges.skylight.io/status/zAvWTaqO0mu1.svg)](https://oss.skylight.io/app/applications/zAvWTaqO0mu1)

Nous utilisons Skylight pour suivre les performances de notre application.

Par ailleurs, nous utilisons [Yabeda](https://github.com/yabeda-rb/yabeda) pour exporter des métriques au format prometheus pour Sidekiq. L’activation se fait via la variable d’environnement `PROMETHEUS_EXPORTER_ENABLED` voir config/env.example.optional .
