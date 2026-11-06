# Local Docker setup

This setup is meant for autonomous local development:

- local login only
- no France Connect, Pro Connect, or SAML login
- no external SMTP provider
- no Sentry, Matomo, Crisp, OCR, ClamAV, or LLM service
- local file storage

It is intentionally not a production deployment recipe.

## What you get

- Rails app on `http://localhost:3000`
- Vite dev server on `http://localhost:3036` for assets and hot reload only
- PostgreSQL with PostGIS
- Redis for local cache

The seeded local credentials are:

- user: `test@exemple.fr`
- password: `this is a very complicated password !`

The same credentials are also created as a `SuperAdmin`. In this Docker profile,
super-admin OTP is disabled to avoid extra local setup.

## Start

1. Build the image:

   ```bash
   docker compose -f compose.local.yml build
   ```

2. Start the infrastructure and app:

   ```bash
   docker compose -f compose.local.yml up app vite db redis
   ```

   Keep that terminal running. Those containers host the web app and Vite server.

3. Seed the database once, in a separate terminal:

   ```bash
   docker compose -f compose.local.yml run --rm app bin/rails db:create db:migrate db:seed
   ```

   This command is a one-off task container. It exits after seeding; that is expected.

4. Open `http://localhost:3000`

   `http://localhost:3036` is not the application UI. It is only the Vite asset server.

## Log in locally

- regular user: `http://localhost:3000/users/sign_in`
- super-admin: `http://localhost:3000/super_admins/sign_in`

Use the seeded credentials from above.

## What is disabled on purpose

- France Connect: `FRANCE_CONNECT_ENABLED=disabled`
- Pro Connect: no `PRO_CONNECT_*` variables are set
- SAML IdP: `SAML_IDP_ENABLED=disabled`
- super-admin OTP: `SUPER_ADMIN_OTP_ENABLED=disabled`
- antivirus: `CLAMAV_ENABLED=disabled`
- external mail providers: all disabled
- telemetry/chat: Sentry, Matomo, Crisp disabled

These values live in `./.env.local.docker`.

## Expected limitations

- PDF generation features that rely on `WEASYPRINT_URL` are not wired in this profile.
- OCR and document AI features are not wired in this profile.
- API-backed identity or business-data enrichments will only work if you add the related credentials.
- This setup uses the Rails `async` job adapter, so it is convenient for local work but not representative of production job execution.

## If you want a fuller local stack

The next step would be to switch `RAILS_QUEUE_ADAPTER=sidekiq` and add a worker service.
That is useful if you want local behavior closer to production, but it is not necessary
to browse the app and log in with seeded users.
