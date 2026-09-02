# AGENTS

This file provides guidelines for agents interacting with or contributing to the code in this repository.

## Project Overview

demarche.numerique.gouv.fr (formerly demarches-simplifiees.fr) is a French government web platform for digitizing administrative procedures. It's a Rails 8.0 application with a React/Stimulus frontend, built to handle sensitive user data with security as a top priority.

## Development Commands

### Setup & Maintenance
- `bin/setup` - Initialize development environment (creates database, installs dependencies)
- `bin/dev` - Start development server (runs web server on port 3000 and Vite bundler in parallel via Overmind)

### Testing
- `bundle exec rspec` - Run all tests
- `bin/parallel-rspec` - Run the suite across 8 processes (~4× faster; run `bin/parallel-rspec --setup` once to create the per-process databases)
- `bundle exec rspec file_path/file_name_spec.rb:line_number` - Run specific test
- `bundle exec rspec --only-failures` - Re-run only failed tests
- `NO_HEADLESS=1 bundle exec rspec spec/system` - Run system tests with visible browser
- `LOG_WEB_CONSOLE=1 bundle exec rspec spec/system` - Display JavaScript console messages in tests
- `MAKE_IT_SLOW=1 bundle exec rspec spec/system` - Add network latency to detect timing bugs (Chromium only)
- Tests use Playwright (Chromium by default; `PLAYWRIGHT_BROWSER=firefox|webkit` to switch)

### Linting & Code Quality
- `bin/rake lint` - Run all linters (Rubocop, haml-lint, herb linter/formatter, i18n-tasks, Brakeman, ESLint, TypeScript, CSS)
- `bin/rake lint:ruby` / `lint:js` / `lint:security` - Run one group only (CI runs the three in parallel jobs; `lint:security` is Brakeman, by far the slowest)
- Brakeman options live in `config/brakeman.yml` (auto-loaded, so a bare `brakeman` matches CI). Every entry in `config/brakeman.ignore` must carry a note saying why the warning is not exploitable, and entries that no longer match any code must be deleted — `lint:security` fails on either.
- `bundle exec rubocop --parallel` - Ruby linting
- `bun lint:js` - JavaScript linting
- `bun lint:types` - TypeScript type checking
- `bun lint:css` - CSS formatting check
- `bun lint:css:fix` - Fix CSS formatting
- `bun lint:herb` - Lint ERB templates
- `bun format:herb` - Format ERB templates
- `bun check-format:herb` - Check Herb template formatting
- `bundle exec i18n-tasks health` - Check translation status

### Other Tasks
- `rails generate component NAME` - Generate a new ViewComponent
- `rails generate maintenance_tasks:task task_name` - Generate maintenance task for database operations/backfills
- View local emails at http://localhost:3000/letter_opener

## Architecture

### Core Domain Models

The application revolves around administrative procedures and their submissions:

**Procedure** - An administrative form template created by administrators
- State machine: `brouillon` (initial) → `publiee` → `close` or `depubliee`
  - `brouillon`: Draft procedure being edited
  - `publiee`: Published and accepting dossiers
  - `close`: Closed, no longer accepting new dossiers
  - `depubliee`: Unpublished (can be republished)
- Uses revision-based versioning via `ProcedureRevision`
- Has `draft_revision` and `published_revision` to support iterative changes
- Contains `TypeDeChamp` (field types) that define the form structure
- Organized using `GroupeInstructeur` for routing submitted dossiers

**Dossier** - A user's submission of a procedure (the filled form)
- State machine: `brouillon` → `en_construction` → `en_instruction` → `accepte`/`refuse`/`sans_suite`
- Contains `Champ` instances (the actual field values)
- Tracks state changes via `Traitement` records
- Extensively uses concerns: DossierCloneConcern, DossierRebaseConcern, DossierStateConcern, etc.
- Notification badges track `dossier_expirant` and `dossier_suppression` states

**TypeDeChamp & Champ Architecture** (critical and complex):

The form system is based on a sophisticated type/value pattern:

- **TypeDeChamp** defines the structure of a field in a procedure's revision
  - 40+ specialized types in `app/models/types_de_champ/` (e.g., `TypesDeChamp::TextTypeDeChamp`, `TypesDeChamp::PieceJustificativeTypeDeChamp`)
  - Stores configuration (label, description, mandatory, conditional logic, etc.)
  - Linked to specific `ProcedureRevision` via `RevisionTypeDeChamp` join table
  - Can have parent-child relationships for repetitions (repeating blocks of fields)
  - Position determines order in the form

- **Champ** stores the actual user-entered value for a TypeDeChamp in a dossier
  - 40+ corresponding types in `app/models/champs/` (e.g., `Champs::TextChamp`, `Champs::PieceJustificativeChamp`)
  - Polymorphic relationship: each Champ subclass handles its specific data type
  - Linked to both its `Dossier` and its `TypeDeChamp`
  - Values stored differently per type: `value` column for text, `data` or `value_json` JSONB for complex types, ActiveStorage attachments for files
  - Champs can be public (filled by user) or private (filled by instructeur)
  - Conditional visibility managed via `Condition` and logic system in `app/models/logic/`

- **Revision System** enables evolving forms without breaking existing dossiers
  - When a procedure is modified, a new revision is created
  - Dossiers track which revision they were created with
  - `DossierRebaseConcern` handles migrating dossiers to newer revisions
  - Each dossier can be rebased to use the latest published revision while preserving data

**User Roles:**
- **Usager** (User) - Fills out and submits dossiers
- **Administrateur** - Creates and manages procedures
- **Instructeur** - Reviews and processes dossiers; has filters and notifications to help with instruction
- **Expert** - Can be invited to review specific dossiers
- **Gestionnaire** - Manages groups of administrateurs (enabled per instance, off by default)
- **SuperAdmin** - Platform team managing the entire system

Note: A single user account can have multiple roles. Different security measures protect access based on user profiles and roles.

### Key Patterns

**Concerns** - Extensively used to organize model behavior
- Model concerns in `app/models/concerns/`
- Controller concerns in `app/controllers/concerns/`
- Prefer concerns over service objects for domain logic

**Services** - Located in `app/services/`, handle complex operations
- Examples: `DossierProjectionService`, `PiecesJustificativesService`, `ApiGeoService`
- LLM services in `app/services/llm/` for AI-powered form improvement (Simpliscore)
- Used for cross-cutting concerns and external API integrations
- Avoid dependency injection in constructors; mock directly in tests

**View Components** - ViewComponent library for reusable UI (not React components)
- Located in `app/components/`
- Examples: `EditableChamp`, `Dossiers::*Component`, `Instructeurs::*Component`

**Jobs** - Async processing with Sidekiq
- Located in `app/jobs/`
- API Entreprise integrations in `app/jobs/api_entreprise/`
- CRON jobs in `app/jobs/cron/`
- LLM processing in `app/jobs/llm/`

**GraphQL API** - Public API for external access
- Schema in `app/graphql/`
- Mutations in `app/graphql/mutations/`
- Types in `app/graphql/types/`
- Batch loading via `GraphQL::Dataloader` (custom sources in `app/graphql/sources/`)

### Frontend Architecture

**Multi-Framework Approach:**
- **Turbo/Hotwire** - Primary navigation and form handling
- **Stimulus** - JavaScript controllers in `app/javascript/controllers/`
- **React** - Complex interactive components in `app/javascript/components/`; React Aria (`react-aria/`) for accessible widgets (e.g. combobox)
- **Vite** - Build tool for JavaScript/CSS (replaces Webpacker)
- **DSFR** - French government design system (@gouvfr/dsfr)

**Template Languages:**
- `.html.erb` - Herb templates (preferred for new code; use bun lint:herb and bun format:herb)
- `.html.haml` - Haml templates (legacy, being phased out)

### Controllers Organization

Controllers are organized by user role:
- `app/controllers/users/` - End-user (dossier submitters)
- `app/controllers/instructeurs/` - Instructors reviewing dossiers
- `app/controllers/administrateurs/` - Procedure creators
- `app/controllers/manager/` - Super-admin (Administrate-based)
- `app/controllers/gestionnaires/` - Group managers (routes gated by `ADMINS_GROUP_ENABLED`)

### External API Integrations

**Authentication:**
- **FranceConnect** - Citizen authentication via government identity provider
- **ProConnect** - Professional/agent authentication for government employees
- Both are critical for secure user authentication and are implemented in `app/controllers/france_connect_controller.rb` and `app/controllers/pro_connect_controller.rb`

**Government APIs:**
- `ApiEntrepriseService` - Company data (SIREN/SIRET)
- `ApiGeoService` - Geographic data (addresses, regions)
- `ApiParticulier` - Citizen data
- Various specialized services: `AnnuaireServicePublicService`, `ApiBretagne`

**Other integrations:**
- **AMI** - Pushes dossier state changes and new messages to the government AMI notification service (`app/services/ami/`, `app/jobs/ami/`); recipient keyed by a hash of the FranceConnect identity, enabled per procedure via Flipper `ami_notifications`
- **RDV Service Public** - OAuth integration for appointment booking (`app/models/rdv.rb`, `app/controllers/rdv_service_public/`)
- **Email delivery** - Multi-provider balancer (`app/lib/balancer_delivery_method.rb`); transactional providers include Brevo (formerly Sendinblue) and Scaleway
- OpenAI-compatible endpoint via langchainrb/ruby-openai (e.g. Albert, the French State LLM), configured with `LLM_URI_BASE`/`LLM_MODEL_NAME`, for AI-powered form improvements (Simpliscore feature)

## Contribution Guidelines

### Code Standards

**Tests Required** - All PRs must include tests
- Model specs in `spec/models/`
- Controller specs in `spec/controllers/`
- System specs in `spec/system/`
- Component specs in `spec/components/`

**Commit Standards:**
- Commit messages in English
- Small, atomic commits
- Fixup commits should be squashed before merge
- Reference issues: `Closes #XXXX` or `Ref #XXXX`
- Core team: all commits must be GPG signed
- External contributors: co-signature by core team member
- Always run linters and tests before commit.

**PR Standards:**
- Keep PRs small
- Include screenshots for visual changes
- **PR titles in French**, using persona format when applicable:
  - `ETQ admin, [description]` (En Tant Que admin)
  - `ETQ usager, [description]` (En Tant Que usager)
  - `ETQ instructeur, [description]`
  - `Tech: [description]` for purely technical changes
- **PR description**: Short summary with essential points for reviewers, avoid excessive technical detail

**Code Cleanliness:**
- Remove dead code and commented code
- Separate refactoring commits from feature commits
- Avoid dependency injection in constructors (directly mock dependencies in tests)

**Accessibility:**
- **Accessibility is a major requirement** for usager and instructeur interfaces
- Follow French accessibility standards (RGAA 4)
- Use semantic HTML and ARIA attributes appropriately
- Test with keyboard navigation and screen readers when implementing UI changes

## Key Configuration

**Ruby version:** See `.ruby-version`
- Use `it` for simple one-line blocks: `ary.map { it.upcase }`
- Use hash value shorthand when key matches variable: `render locals: { user: }`

**Node/JavaScript:** Bun (package manager)
**Database:** PostgreSQL 17
**Job Queue:** Sidekiq
**Caching:** Redis
**Locales:** French (default), English
**Time Zone:** Paris

**Environment:**
- `.env` - Local environment variables (copy from `config/env.example`)

**Maintenance Tasks:**
- Use the `MaintenanceTasks` gem for database operations, backfills, and data migrations
- Generate with `rails generate maintenance_tasks:task task_name`
- Tasks run in background and can be monitored via admin interface

## Security Considerations

- All code handles potentially sensitive government data
- **Image Processing**: Uploaded images are processed based on their nature
  - Identity documents (`Champs::TitreIdentiteChamp`) receive watermarks for privacy protection
  - Different attachment types get appropriate representations (previews, thumbnails)
  - Processing logic in `BlobProcessorConcern`, using libvips via `ruby-vips`
- AGPL license - all code must be compatible
- Commits should be signed (GPG for core team)
- Brakeman security scanner runs in CI

## Testing Philosophy

- Use TDD as much as possible.
- Prefer system specs for user-facing features
- **Prefer Oaken seeds over factories.** The whole world in `db/seeds/` (users, procedures, dossiers, avis, entreprise, messagerie) is seeded once per suite via `oaken/rspec_setup`; labeled accessors (`users.usager`, `administrateurs.default`, `procedures.individual`, `dossiers.en_construction`, `avis.pending`, …) are available in every example, and per-example mutations roll back. Reach for a seeded record first; only fall back to a factory when the spec needs attributes the seeds don't provide.
- Scenario seeds in `db/seeds/cases/` (champs, sva, …) load per group with `before_all { seed "cases/sva" }` — add a new case file when several specs need the same non-trivial setup.
- **When touching a spec that builds generic records with factories, migrate it to seeds if a seeded record (or a new case seed) fits** — it makes the suite faster and the setup shared. Keep FactoryBot (`spec/factories/`) for records whose attributes are the point of the test.
- Seed-safety: never assert global counts or unparameterized scopes (`Procedure.all`, raw SQL over a table) — scope queries to the spec's records, or declare `empty_seeds Model` at the top of the group (see `spec/support/oaken.rb`). Specs about an admin's own aggregate state should use the seeded `administrateurs.blank`.
- Use `let_it_be` (test-prof) for shared setup where possible
- Support files in `spec/support/`
- RSpec helper: `rails_helper.rb` (includes Rails), `spec_helper.rb` (no Rails)
- Don't over test; test suite execution must be fast.

## Notable Technical Details

- Uses `AASM` gem for state machines (Dossier states)
- Flipper for feature flags
- **Authorization**: mostly handled directly in controllers; Pundit policies (`app/policies/`, incl. per-type `app/policies/champs/`) handle champ-level authorization
- Devise for authentication (with 2FA support)
- FranceConnect & ProConnect for government identity integration
- GraphQL::Dataloader for batched GraphQL queries (custom sources in `app/graphql/sources/`)
- Discard gem for soft deletes
- **PDF documents** (attestation de dépôt) are native Typst templates in `lib/typst/root/` (the typst compilation root: templates, `images/`, `fonts/`, nothing else is readable by a template), each fed by a `Typst::*Payload` class of `app/models/typst/` (named after its template, builds the already-localized JSON payload) and rendered by `TypstService.render(payload)`; each document is gated per procedure by its own Flipper flag (`attestation_depot_typst`) by a `*Service.render` (`AttestationDepotService`) where any failure of the Typst path falls back to the legacy WeasyPrint renderer. `lib/typst/root/theme.typ` holds the layout and its header lists the charte graphique de l'État references (letterhead grid, bloc-marque, typography, colours) to follow for any new template or layout change
- Strong Migrations for database migration linting
- Skylight for performance monitoring
- Sentry for error tracking
- Prometheus metrics exported for Sidekiq (via Yabeda)
- langchainrb + ruby-openai for LLM integration (OpenAI-compatible endpoint; no vendor-specific gem)
- `RetryableFetchError` for graceful external API degradation
- Object storage via ActiveStorage: default service set by `ACTIVE_STORAGE_SERVICE` (OpenStack); an `amazon` S3 service (via ds_proxy)

## Support

User support is handled via **Crisp** integration.


Last updated: July 20, 2026.
