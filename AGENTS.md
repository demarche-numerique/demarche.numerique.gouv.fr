# AGENTS

Guidelines for agents contributing to this repository.

## Project

demarche.numerique.gouv.fr (formerly demarches-simplifiees.fr) — French government platform for digitizing administrative procedures. Rails, React/Stimulus, DSFR design system. Everything here touches sensitive citizen data.

## Commands

- Local emails land at http://localhost:3000/letter_opener — mounted in `config/routes/misc.rb`, not the root routes file.

### Tests
- `bundle exec rspec path/to/file_spec.rb:LINE` — a single test; prefer this to a full run
- `bin/parallel-rspec` — whole suite over 8 processes (~4× faster); run `bin/parallel-rspec --setup` once to create the per-process databases
- `bundle exec rspec --only-failures` — re-run failures
- System tests run on Playwright (Chromium; `PLAYWRIGHT_BROWSER=firefox|webkit` to switch). Env flags: `NO_HEADLESS=1` (visible browser), `LOG_WEB_CONSOLE=1` (JS console output), `MAKE_IT_SLOW=1` (adds network latency, surfaces timing bugs; Chromium only)

### Lint
- `bin/rake lint` — everything. `lint:ruby` / `lint:js` / `lint:security` run one group (CI runs the three as parallel jobs; `lint:security` is Brakeman and by far the slowest)
- Individually: `bundle exec rubocop --parallel`, `bun lint:js`, `bun lint:types`, `bun lint:css` (`bun lint:css:fix`), `bun lint:herb` (`bun format:herb`), `bundle exec i18n-tasks health`
- Brakeman reads `config/brakeman.yml` automatically, so a bare `brakeman` matches CI. Every `config/brakeman.ignore` entry must carry a note saying why the warning is not exploitable, and entries that no longer match any code must be deleted — `lint:security` fails on either.

### Generators
- `rails generate component NAME` — a ViewComponent
- `rails generate maintenance_tasks:task NAME` — backfills and data migrations go through the MaintenanceTasks gem, never a one-off rake task

## Domain vocabulary

- **Procedure** — a form template. States: `brouillon` → `publiee` → `close` | `depubliee`.
- **Dossier** — a usager's filled submission. States: `brouillon` → `en_construction` → `en_instruction` → `accepte` | `refuse` | `sans_suite`.
- **TypeDeChamp / Champ** — a field's definition vs. its value. A new field type means a subclass on both sides (`app/models/types_de_champ/`, `app/models/champs/`). A champ is either public (filled by the usager) or private (filled by the instructeur) — check which before exposing one.
- **Revisions** — editing a published procedure creates a new `ProcedureRevision`; existing dossiers keep theirs until rebased (`DossierRebaseConcern`). Anything touching champs must still work for a dossier sitting on an older revision.
- **Roles** — usager, instructeur, expert (invited on a single dossier), administrateur, gestionnaire (manages groups of administrateurs), super admin. One account can hold several roles, and controllers are namespaced per role.

## Data volumes

Production row counts, from the cleaned production dump of **2026-09-07** (update the date when refreshing). Every scan of `dossiers` or `active_storage_blobs` is a scan of tens of millions of rows: check the plan on a production-sized table before shipping a batch query.

| Table | Rows |
|---|---|
| `active_storage_blobs` | 168 M (2.1 M soft-deleted) |
| `active_storage_attachments` | 128 M |
| `active_storage_variant_records` | 29 M |
| `dossier_notifications` | 17 M |
| `users` | 11.6 M |
| `dossiers` | 11.5 M: accepte 6.7 M, en_instruction 2.2 M, sans_suite 0.85 M, refuse 0.68 M, en_construction 0.66 M, brouillon 0.54 M |
| `deleted_dossiers` | 10.8 M |
| `follows` | 9.1 M |
| `individuals` | 6.6 M |
| `procedures` / `procedure_revisions` / `groupe_instructeurs` / `instructeurs` | 101 k / 231 k / 214 k / 177 k |

`champs` was not measured (it is the largest table). last id : 1_566_501_743, assume 1B

## Conventions

- Ruby 3.4: use `it` in one-line blocks (`ary.map { it.upcase }`) and hash shorthand when the key matches the variable (`locals: { user: }`).
- Domain logic belongs in concerns, not service objects. `app/services/` is for cross-cutting work and external API clients, which degrade through `RetryableFetchError`.
- No dependency injection in constructors — mock the dependency directly in the test.
- Reusable UI is a ViewComponent. React is reserved for complex interactive widgets (React Aria for the accessible ones).
- Write new templates in ERB/Herb; `.haml` is legacy and being phased out.
- Authorization lives in the controllers, except champ-level access, which goes through Pundit policies (`app/policies/champs/`).
- Feature flags go through Flipper. Soft deletes go through Discard — check whether a model is discardable before destroying or counting rows.
- Migrations are linted by Strong Migrations, so a naive one gets rejected.
- User-facing strings are translated in **fr and en** (French is the default locale, Paris the time zone). A public GraphQL API (`app/graphql/`) exposes part of the domain: changing what it returns is a breaking change for integrators.
- PDF documents (attestation de dépôt) are native Typst templates in `lib/typst/root/`, the compilation root: a template can read nothing outside it (templates, `images/`, `fonts/`). Each template is fed by a `Typst::*Payload` class in `app/models/typst/` (named after it, builds the already-localized JSON payload), rendered through `TypstService.render(payload)`, and gated per procedure by its own Flipper flag (`attestation_depot_typst`) in a `*Service.render` (`AttestationDepotService`) that falls back to the legacy WeasyPrint renderer on any failure of the Typst path. `lib/typst/root/theme.typ` holds the layout, and its header lists the charte graphique de l'État references (letterhead grid, bloc-marque, typography, colours) to follow for any new template or layout change.
- Remove dead and commented-out code. Keep refactoring commits separate from feature commits.

## Validations

- Prefer a built-in validator (`comparison`, `numericality`, `inclusion`, `length`, `format`, `presence`, `uniqueness`) over a hand-written `validate :method`. Write the method only for business logic a built-in cannot express, or when it produces several distinct errors that matter to the user.
- Pick the cheapest form the bound allows: a frozen constant for a static list (`in: NAMES`), a symbol when the bound is read off the record (`other_than: :id`), a lambda **only** when the bound genuinely moves over time (`greater_than: -> (_) { Date.current }`, which a constant would freeze at class load). A lambda over a static list re-evaluates at every validation for nothing.
- `presence` and `comparison` go in **two separate `validates` calls**, with `allow_nil: true` on the comparison one only. Sharing a call breaks both ways: `comparison` reports a nil value as `:blank` too, so the message shows twice, and `allow_nil` applies to the whole call, silently disabling the presence check.
- Override the default messages in i18n under `activerecord.errors.models.<model>.attributes.<attr>.<kind>` (fr **and** en) — the built-in ones quote the raw bound ("doit être supérieur à 2026-09-02").
- Specs assert the attribute **and** the error kind (`expect(record.errors).to be_of_kind(:attr, :kind)`), never a bare `be_invalid`. Beware: with `inclusion: { message: :custom_symbol }` the kind stays `:inclusion` — the symbol only drives the translation lookup.

## Testing

- Use TDD where possible, prefer system specs for user-facing behaviour, and don't over-test: suite execution must stay fast. Every PR carries tests.
- **Seeds before factories.** The whole world in `db/seeds/` is loaded once per suite (`oaken/rspec_setup`); labeled accessors (`users.usager`, `administrateurs.default`, `procedures.individual`, `dossiers.en_construction`, `avis.pending`, …) are available in every example, and per-example mutations roll back. Fall back to FactoryBot only when the record's attributes are the point of the test.
- Shared non-trivial setup belongs in a scenario seed (`db/seeds/cases/`), loaded per group with `before_all { seed "cases/sva" }`. When touching a spec that builds generic records with factories, migrate it to seeds if one fits.
- Seed-safe assertions: never assert global counts or unparameterized scopes (`Procedure.all`, raw SQL over a table). Scope queries to the spec's own records, or declare `empty_seeds Model` at the top of the group (see `spec/support/oaken.rb`). Specs about an admin's own aggregate state use the seeded `administrateurs.blank`.
- Use `let_it_be` (test-prof) for shared setup.

## Commits & pull requests

- Commit messages in English. Small, atomic commits; squash fixups before merge; reference issues with `Closes #XXXX` or `Ref #XXXX`.
- Core team signs every commit (GPG). External contributions are co-signed by a core team member.
- Run the linters and the affected specs before committing.
- Keep PRs small, with screenshots for visual changes.
- **PR titles in French**, persona-first when it applies: `ETQ usager, …`, `ETQ instructeur, …`, `ETQ admin, …`, or `Tech: …` for purely technical work.
- PR description: a short summary with what a reviewer actually needs — not exhaustive technical detail.

## Accessibility

**RGAA 4 compliance is a hard requirement** for the usager and instructeur interfaces, not a nice-to-have. Use semantic HTML and ARIA attributes where they are needed, and check keyboard navigation and screen-reader output on any UI change.

## Security

- Brakeman runs in CI, and the codebase handles sensitive government data throughout.
- Identity documents (`Champs::TitreIdentiteChamp`) are watermarked on upload for privacy; image processing goes through `BlobProcessorConcern` (libvips via `ruby-vips`).
- AGPL license — every dependency and contribution must be compatible with it.

<!--
Maintainers: keep this file under 200 lines. It is loaded into every agent session
(Claude Code reads it through CLAUDE.md -> @AGENTS.md), and adherence drops as it grows:
a bloated instruction file gets ignored wholesale rather than filtered.

Before adding a line, ask whether its absence would actually cause a mistake. Anything an
agent can learn by reading the code — directory layouts, dependency lists, architecture
overviews, file-by-file descriptions — belongs in the code, not here. So do version
numbers and anything else that goes stale. Keep pitfalls, rationale, and conventions that
differ from the tools' defaults.

Block HTML comments like this one are stripped before the file enters the context window.

Last reviewed: 2026-09-07.
-->
