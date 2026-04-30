# demarche.numerique.gouv.fr

> [!NOTE]
> [Lire la version française du README](README.fr.md)

## Context

[demarche.numerique.gouv.fr](https://demarche.numerique.gouv.fr) is a web platform designed to address the French government's urgent need to comply with the directive for 100% digitization of administrative procedures.

## How to contribute?

demarche.numerique.gouv.fr is [open source](https://en.wikipedia.org/wiki/Open-source_software) software under the AGPL license.

Would you like to make changes or improvements? Read our [contribution guide](CONTRIBUTING.md).

## Development setup

### Technical dependencies

#### All environments

- postgresql (version >= 15)
- libvips-dev (image processing and watermark generation)
- gsfonts (fonts for watermark text rendering)

We are currently migrating from `delayed_job` to `sidekiq` for asynchronous job processing.
To run sidekiq, you will need:

- redis

- lightgallery: a license has been purchased to support the project, but it is not required if the library is used as part of an open source application.

#### Development

- rbenv: see https://github.com/rbenv/rbenv-installer#rbenv-installer--doctor-scripts
- Bun: see https://bun.sh/docs/installation

#### Tests

- Chrome
- chromedriver:
  - Mac: `brew install chromedriver`
  - Linux: see https://developer.chrome.com/blog/chrome-for-testing

If Chrome's installation location is non-standard, or if you're using Brave or Chromium instead,
you may need to override the path to the Chrome binary for your machine, for example:

```ruby
# create file spec/support/spec_config.local.rb

Selenium::WebDriver::Chrome.path = "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"

# Must exactly match the browser version
Webdrivers::Chromedriver.required_version = "103.0.5060.53"
```

It's also possible to automatically install and update when running `bin/update` by defining the `UPDATE_WEBDRIVER` environment variable. The binaries will be installed in the `~/.local/bin/` directory, which must be manually added to your path.

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

### Launching the application

Start the application server like this:

    bin/dev

The application will then run at `http://localhost:3000` with a worker for jobs and the vitejs bundler running in parallel.

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

Tests need their own database, and some of them use Selenium to run in a browser. Don't forget to create the test database and install Chrome and chromedriver to run all tests.

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

- Display JavaScript error logs from the browser console (`console.error('hello')`)

        JS_LOG=debug,log,error bin/rspec spec/system

- Increase latency during end-to-end tests to detect stubborn bugs

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
