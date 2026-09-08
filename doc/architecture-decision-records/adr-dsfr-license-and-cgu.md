# Accepting the DSFR terms of use, and living with an AGPL repository

## Context

We depend on `@gouvfr/dsfr`, the French State Design System. Until now this was a
plain npm dependency with no strings attached at install time. Version `1.15.0`
changed that: the package now ships a `preinstall` hook that refuses to install
unless the consuming project has explicitly accepted the DSFR *modalités
d'utilisation* (terms of use).

Three separate legal artefacts are involved, and they are easy to conflate:

1. **The code licence.** `LICENSE.md` in the package states the DSFR code is
   licensed under **Etalab Open Licence 2.0** — a permissive licence, compatible
   with our AGPL-3.0 repository. This has not changed and is not in question.
2. **The terms of use** (`doc/legal/cgu.md`, `cguVersion: 1.0.1`, dated
   20 July 2026). These are *not* a licence: they restrict who may use the DSFR
   and where. The relevant clauses:
   - §7 and §14: the resources are intended solely for websites served under a
     `.gouv.fr` domain, or State mobile applications.
   - §10: State operators must additionally obtain approval from their
     supervising ministry.
   - §47/§48: State services must request a *agrément de principe* before
     starting, and a *agrément définitif* before going live. (Both request forms
     are, as it happens, hosted on this very platform.)
   - §20: the Marianne typefaces carry their own separate terms.
3. **The Marianne fonts**, out of scope here but worth flagging: we vendor them
   by hand in `app/assets/fonts/` and `public/fonts/`, desynchronised from the
   npm package.

We are a State service serving `demarche.numerique.gouv.fr`, so clauses 7, 10
and 14 are satisfied for *our own* deployment. The question that actually needs
answering is a different one.

### The real question: our downstream reusers

This repository is published under **AGPL-3.0**. Anyone may clone it, and the
AGPL explicitly grants them the right to run and redistribute it. But the DSFR
terms forbid exactly that class of reuse: an entity outside the State
administration, serving the application on a non-`.gouv.fr` domain, would be in
breach of §7/§14 while being perfectly within their AGPL rights.

This is not a new contradiction — it exists today with 1.14.3, since the terms
predate the `preinstall` hook. What 1.15.x changes is that the contradiction is
now *materialised in the build*: accepting the terms becomes a versioned,
committed act rather than an implicit one. That makes it the right moment to
state our position rather than leave it unaddressed.

We do not have the standing to license the DSFR to third parties, and we cannot
sublicense it under the AGPL. What we can do is stop implying that we do.

### An incoherence found along the way

`publiccode.yml:23` declares `license: GPL-3.0-or-later`, while `LICENSE.txt` is
the **AGPL-3.0**. This is a pre-existing error unrelated to the DSFR upgrade,
but any statement we make about licensing is undermined while it stands.

### What the install gate actually does

`scripts/preinstall.js` reads `.dsfr.yml` at the project root and compares its
`accept-license` value against `cguVersion` in the packaged terms. It passes if
they match, or if `DSFR_ACCEPT_LICENSE=1` is set in the environment. Otherwise
it calls `process.exit(1)`.

Measured empirically with our toolchain (Bun 1.3.1, clean project, no
`.dsfr.yml`):

```
+ @gouvfr/dsfr@1.15.2
1 package installed
Blocked 1 postinstall. Run `bun pm untrusted` for details.
```

Exit code `0`, `dist/` present and complete. **Bun does not run the hook by
default**, because lifecycle scripts only execute for packages listed in
`trustedDependencies`. Out of the box the gate is inert for us, silently — which
is the situation the decision below deliberately reverses.

That is a technical fact, not a decision. It means the upgrade is not blocked —
but it also means that doing nothing would leave us benefiting from a silent
bypass of a consent mechanism whose whole purpose is to be explicit. Consent
that only holds because the package manager failed to ask for it is not consent.

## Options considered

### Set `DSFR_ACCEPT_LICENSE=1` in CI

Cheapest. But the acceptance lives in CI configuration, invisible to anyone
reading the repository, and is not versioned alongside the terms it accepts. It
also would not apply to a developer's local install, so the two environments
would disagree about whether we have consented.

### Commit `.dsfr.yml` with `accept-license: 1.0.1`

Explicit, versioned, reviewable, and identical in CI and locally. The accepted
version is recorded in git history, so a future bump of the terms produces a
visible diff and a deliberate re-acceptance rather than a silent drift. This is
also the mechanism the DSFR team designed for.

The cost is that the file is a declaration made on behalf of the organisation,
not a technical setting. It must be signed off accordingly.

### Add `@gouvfr/dsfr` to `trustedDependencies`

Makes the gate actually run and fail loudly when unaccepted. Combined with
`.dsfr.yml` it turns consent into an enforced invariant rather than a
convention.

The cost is that it lets an upstream script run at install time in CI. That
script is `scripts/preinstall.js`: it reads two files, compares two strings and
calls `process.exit(1)`. Nothing else — no network, no writes.

Adopted, because committing the file alone buys less than it appears to. Under
Bun the hook never runs, so a revision of the terms upstream would pass
completely unnoticed and `.dsfr.yml` would quietly become a false statement.
Measured on a clean project:

| `.dsfr.yml` | `trustedDependencies` | `bun install` |
|---|---|---|
| absent | absent | passes, `Blocked 1 postinstall` |
| absent | present | **fails** — `[NO_YML]` |
| `accept-license: 1.0.1` | present | passes |
| `accept-license: 1.0.0` | present | **fails** — `[UPDATE-1.0.0->1.0.1]` |

Only the last row has real value: it is the one that tells us the terms have
changed. Verified again in this repository after the change.

### Do nothing and rely on Bun's blocking

Rejected. It works, and it is dishonest.

## Decision

1. **Accept the DSFR terms of use explicitly**, by committing a `.dsfr.yml` at
   the repository root containing `accept-license: 1.0.1`, and by adding
   `@gouvfr/dsfr` to `trustedDependencies` so the declaration is enforced rather
   than decorative. Do not rely on `DSFR_ACCEPT_LICENSE`, which lives outside the
   repository and would let CI and local installs disagree about whether we have
   consented.

   With both in place, a revision of the terms upstream stops the install with
   `[UPDATE-<accepted>-><current>]`. That is deliberate: it forces a human to
   read what changed and to re-accept, instead of letting the version drift
   silently. Re-accepting means bumping the value in `.dsfr.yml`, which leaves a
   dated, reviewable line in git history.

2. **State the DSFR carve-out in the README**, in both language versions: the
   AGPL covers our code, but the bundled `@gouvfr/dsfr` assets are governed by
   the DSFR terms of use, which restrict use to State services on `.gouv.fr`
   domains. A third party reusing this repository must remove or replace the
   DSFR assets. We grant what we can grant and no more; making this explicit
   protects reusers, who would otherwise discover the restriction only if
   challenged.

3. **Fix `publiccode.yml:23`** to `AGPL-3.0-or-later`, matching `LICENSE.txt`.

4. **Pin `@gouvfr/dsfr` to an exact version** rather than the current `^1.14.3`.
   A caret range means any lockfile regeneration silently adopts a new DSFR
   version — and therefore potentially a new revision of the terms — without a
   decision being made. Given that the terms are now versioned and that we have
   just established the hook will not warn us, an open range is the wrong
   default.

Points 1 and 4 are applied. Points 2 and 3 remain to be done.
