# demarches-simplifiees.fr

## Contexte

[demarches-simplifiees.fr](https://www.demarches-simplifiees.fr) est un site web conçu afin de répondre au besoin urgent de l’État d’appliquer la directive sur le 100 % dématérialisation pour les démarches administratives.

## Comment contribuer ?

demarches-simplifiees.fr est un [logiciel libre](https://fr.wikipedia.org/wiki/Logiciel_libre) sous licence AGPL.

Vous souhaitez y apporter des changements ou des améliorations ? Lisez notre [guide de contribution](CONTRIBUTING.md).

## Installation pour le développement

### Dépendances techniques

#### Tous environnements

- postgresql (version >= 15)
- imagemagick et gsfonts pour générer les filigranes sur les titres d’identité ou générer des minitiatures d’images.

> [!WARNING]
> Pensez à restreindre la policy d’ImageMagick pour bloquer l’exploitation d’images malveillantes.
> La configuration par défaut est généralement insuffisante pour des images provenant du web.
> Par exemple sous debian/ubuntu dans `/etc/ImageMagick-6/policy.xml` :

```xml
<!-- en plus de la policy par défaut, ajoutez à la fin du fichier -->
<policymap>
    <policy domain="coder" rights="none" pattern="*"/>
    <policy domain="coder" rights="read | write" pattern="{JPG,JPEG,PNG,JSON}"/>
    <policy domain="module" rights="none" pattern="{MSL,MVG,PS,SVG,URL,XPS}"/>
</policymap>
```

Nous sommes en cours de migration de `delayed_job` vers `sidekiq` pour le traitement des jobs asynchrones.
Pour faire tourner sidekiq, vous aurez besoin de :

- redis

- lightgallery : une license a été souscrite pour soutenir le projet, mais elle n’est pas obligatoire si la librairie est utilisée dans le cadre d’une application open source.

#### Développement

- rbenv : voir https://github.com/rbenv/rbenv-installer#rbenv-installer--doctor-scripts
- Bun : voir https://bun.sh/docs/installation

#### Tests

- Chrome
- chromedriver :
  - Mac : `brew install chromedriver`
  - Linux : voir https://developer.chrome.com/blog/chrome-for-testing

Si l’emplacement d’installation de Chrome n’est pas standard, ou que vous utilisez Brave ou Chromium à la place,
il peut être nécessaire d’overrider pour votre machine le path vers le binaire Chrome, par exemple :

```ruby
# create file spec/support/spec_config.local.rb

Selenium::WebDriver::Chrome.path = "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"

# Must exactly match the browser version
Webdrivers::Chromedriver.required_version = "103.0.5060.53"
```

Il est également possible de faire une installation et mise à jour automatique lors de l’exécution de `bin/update` en définissant la variable d’environnement `UPDATE_WEBDRIVER`. Les binaires seront installés dans le repertoire `~/.local/bin/` qui doit être rajouté manuellement dans le path.

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

### Lancement de l’application

On lance le serveur d’application ainsi :

    bin/dev

L’application tourne alors à l’adresse `http://localhost:3000` avec en parallèle un worker pour les jobs et le bundler vitejs.

### Utilisateurs de test

En local, un utilisateur de test est créé automatiquement, avec les identifiants `test@exemple.fr`/`this is a very complicated password !`. (voir [db/seeds.rb](https://github.com/betagouv/demarches-simplifiees.fr/blob/dev/db/seeds.rb))

### Programmation des tâches récurrentes

    rails jobs:schedule

### Voir les emails envoyés en local

Ouvrez la page [http://localhost:3000/letter_opener](http://localhost:3000/letter_opener).

### Mise à jour de l’application

Pour mettre à jour votre environnement de développement, installer les nouvelles dépendances et faire jouer les migrations, exécutez :

    bin/update

### Exécution des tests (RSpec)

Les tests ont besoin de leur propre base de données et certains d’entre eux utilisent Selenium pour s’exécuter dans un navigateur. N’oubliez pas de créer la base de test et d’installer chrome et chromedriver pour exécuter tous les tests.

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

- Afficher les logs js en error issus de la console du navigateur `console.error('coucou')`

        JS_LOG=debug,log,error bin/rspec spec/system

- Augmenter la latence lors de tests end2end pour déceler des bugs récalcitrants

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
