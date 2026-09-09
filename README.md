# demarche.numerique.gouv.fr

> [!NOTE]
> [Lire la version française du README](README.fr.md)

## Context

[demarche.numerique.gouv.fr](https://demarche.numerique.gouv.fr) is a web platform designed to address the French government's urgent need to comply with the directive for 100% digitization of administrative procedures.

## How to contribute?

demarche.numerique.gouv.fr is [open source](https://en.wikipedia.org/wiki/Open-source_software) software under the AGPL license.

The French State design system (`@gouvfr/dsfr`) and the State brand assets bundled in this repository are the exception to the AGPL. Up to version 1.14.3 the DSFR was published under the MIT licence, and its terms expressly authorised users outside the administration to reuse its source code. That is no longer true: since 1.15.1 the code is under the [Etalab 2.0 licence](https://github.com/GouvernementFR/dsfr/blob/main/LICENSE.md), which states that the DSFR "must not be used by entities outside the administration, and limits its replicability outside a `.gouv.fr` domain name", and its use is governed by [terms of use](https://github.com/GouvernementFR/dsfr/blob/main/doc/legal/cgu.md) that you accept by the sole act of downloading and using it, and from which we cannot exempt you.

In practice: we do not commit a `.dsfr.yml` file, so that accepting those terms remains your decision, and installing the JavaScript dependencies will ask you explicitly (see [`doc/DEPLOYMENT.md`](doc/DEPLOYMENT.md)). If your deployment is not entitled to them, remove or replace those assets — including the Marianne typefaces vendored in `app/assets/fonts/`, `public/fonts/` and `lib/prawn/fonts/marianne/`, and the Marianne logos in `app/assets/images/`, which carry [separate terms](https://www.info.gouv.fr/marque-de-letat/la-typographie) of their own.

Would you like to make changes or improvements? Read our [contribution guide](CONTRIBUTING.md).

## Development setup

### Technical dependencies

#### All environments

- postgresql (version >= 15)
- libvips-dev (version >= 8.13, image processing and watermark generation)
- gsfonts (fonts for watermark text rendering)
- zip (Info-ZIP 3.0 or later, used to build the export and archive files)

  On macOS the system `/usr/bin/zip` is an Apple build that dropped support for
  the `-UN=UTF8` flag, which we pass to keep accented filenames intact. Export
  and archive specs then fail with `zip error: Invalid command arguments (short
  option 'N' not supported)`. Install Info-ZIP and put it first in your `PATH`:

      brew install zip
      echo 'export PATH="/opt/homebrew/opt/zip/bin:$PATH"' >> ~/.zshrc

- redis

- lightgallery: a license has been purchased to support the project, but it is not required if the library is used as part of an open source application.

#### Development

- rbenv: see https://github.com/rbenv/rbenv-installer#rbenv-installer--doctor-scripts
- Bun: see https://bun.sh/docs/installation

#### Tests

System tests run with Playwright (Chromium by default). The browser is installed by `bin/setup` (or `bun playwright install chromium`). Set `PLAYWRIGHT_BROWSER=firefox` or `PLAYWRIGHT_BROWSER=webkit` to run them in another browser.

### Creating database roles

The information needed to initialize the database must be pre-configured manually using the following procedure:

    su - postgres
    psql
    > create user tps_development with password 'tps_development' superuser;
    > create user tps_test with password 'tps_test' superuser;
    > \q

### Initializing the development environment

On Ubuntu, some packages must be installed first:

    sudo apt-get install libcurl3 libcurl3-gnutls libcurl4-openssl-dev libcurl4-gnutls-dev zlib1g-dev

To initialize the development environment, run the following command:

    bin/setup

The first run stops before installing the JavaScript dependencies, because
`@gouvfr/dsfr` will not install until its [terms of use](https://github.com/GouvernementFR/dsfr/blob/main/doc/legal/cgu.md)
have been accepted. `bin/setup` has just created your `.env` from
`config/env.example`: read the terms, uncomment `DSFR_ACCEPT_LICENSE` in that
file if you are entitled to use the DSFR, and run `bin/setup` again. Your `.env`
is never committed — we deliberately do not ship an acceptance file, so that the
decision is made once per machine rather than inherited from this repository.

### Launching the application

Start the application server like this:

    bin/dev

The application will then run at `http://localhost:3000` with the vitejs bundler running in parallel.

Async jobs run in the web process by default (the `async` adapter). To go through sidekiq instead,
set `RAILS_QUEUE_ADAPTER=sidekiq` in your `.env` and run `bundle exec sidekiq` alongside `bin/dev`.

### Test users

Locally, a test user is automatically created with the credentials `test@exemple.fr`/`this is a very complicated password !`. (see [db/seeds.rb](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/blob/dev/db/seeds.rb))

### Scheduling recurring tasks

    rails jobs:schedule

### Viewing emails sent locally

Open the page [http://localhost:3000/letter_opener](http://localhost:3000/letter_opener).

### Updating the application

To update your development environment, install new dependencies, and run migrations:

    bin/update

### Running tests (RSpec)

Tests need their own database, and some of them run in a browser through Playwright. Don't forget to create the test database and install the Playwright browser (`bun playwright install chromium`) to run all tests.

To run the application tests, several options are available:

- Run all tests

        bin/rake spec
        bin/rspec

- Run a specific test

        bin/rake spec SPEC=file_path/file_name_spec.rb:line_number
        bin/rspec file_path/file_name_spec.rb:line_number

- Run all tests in a file

        bin/rake spec SPEC=file_path/file_name_spec.rb
        bin/rspec file_path/file_name_spec.rb

- Only rerun tests that previously failed

        bin/rspec --only-failures

- Run one or more system tests with a visible browser

        NO_HEADLESS=1 bin/rspec spec/system

- Display JavaScript logs from the browser console (`console.error('hello')`)

        LOG_WEB_CONSOLE=1 bin/rspec spec/system

- Increase network latency during end-to-end tests to detect stubborn timing bugs (Chromium only)

        MAKE_IT_SLOW=1 bin/rspec spec/system

### Adding tasks to run during deployment

        rails generate maintenance_tasks:task task_name

### Linting

The project uses several linters to check code readability and quality.

- Run all linters: `bin/rake lint`
- Check the status of translations: `bundle exec i18n-tasks health`
- [AccessLint](http://accesslint.com/) runs automatically on PRs

### Regenerating binstubs

    bundle binstub railties --force
    bin/rake rails:update:bin

## Deployment

See deployment notes in [DEPLOYMENT.md](doc/DEPLOYMENT.md)

> [!IMPORTANT]
> The application must be deployed behind a reverse proxy (e.g. nginx, HAProxy) that overwrites the `X-Forwarded-For` header with the real client IP.
>
> Several IP-based security mechanisms rely on `request.remote_ip` to identify the client:
>
> - rate limiting (`Rack::Attack`)
> - trusted networks gate (skip 2FA for instructeurs coming from a trusted IP)
> - IP allow-lists for API tokens (`whitelisted_ip_*` on API tokens)
>
> Without a proxy that sanitizes `X-Forwarded-For`, a client can spoof the header and bypass these protections.

## Common tasks

### Super-admin account management tasks

Super-admin account management tasks are available in the `superadmin` namespace.
To list them: `bin/rake -D superadmin:`.

### Support tasks

Support tasks are available in the `support` namespace.
To list them: `bin/rake -D support:`.

## Performance

[![View performance data on Skylight](https://badges.skylight.io/status/zAvWTaqO0mu1.svg)](https://oss.skylight.io/app/applications/zAvWTaqO0mu1)

We use Skylight to monitor our application's performance.

Additionally, we use [Yabeda](https://github.com/yabeda-rb/yabeda) to export Prometheus-format metrics for Sidekiq. This is activated via the `PROMETHEUS_EXPORTER_ENABLED` environment variable (see config/env.example.optional).
