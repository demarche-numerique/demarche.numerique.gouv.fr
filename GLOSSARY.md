# Glossary

The reference vocabulary of demarche.numerique.gouv.fr, in French and in
English. It says how each domain concept is called in the product (French),
in the English UI, in code, and where an older name is frozen.

This is a living document. Rows marked **settled** are the names to use today;
rows marked **proposed** are the current best pick and may change. When a row
changes, update the changelog at the end. Nothing here obliges anyone to rename
existing code: it fixes the names for *new* code, *new* copy, and for cleanups
when they happen.

## How to read a row

| Column | Meaning |
|---|---|
| **French** | The product term, as spoken by the team and shown in the French UI. French UI copy follows this column. |
| **English (UI)** | The term for English copy: UI strings, emails, documentation. A translation of the *concept*, never of the word. |
| **English (code)** | The identifier for new code: methods, attributes, concerns, jobs, routes, GraphQL v3. `snake_case` here means Ruby and columns; PascalCase means classes and GraphQL types. |
| **Frozen** | Where the legacy name is locked and must not be renamed: a table or column, an AASM state value, a GraphQL v2 name. Absent means nothing is frozen. |

## Rules

### The register

One coherent English register: **public-sector application review**. The
sentence everything must read against is:

> An **applicant** submits an **application** to a **procedure**; the procedure
> routes it to a **team**; **reviewers** review it, ask **experts** for
> **opinions** and the applicant for **changes**, and issue a **decision**.

Two traps produced the current English UI and are banned:

- **Literal translation.** "File" for dossier, "instructor" for instructeur,
  "instruction" for instruction. False friends: an English reader hears a
  folder, a teacher, a directive.
- **Untranslated French.** "Dossier", "démarche", "avis" left as-is in English
  copy or in new code.

### Words never to use in English

| Never | Why | Use instead |
|---|---|---|
| file | Means a folder or a computer file. The English UI says it about 200 times today. | application (the dossier), attachment or document (a PJ) |
| instructor, instruct, instruction | Teaching and directives. | reviewer, review, under review |
| case, caseworker | Social work and welfare in British English; lets "case" leak everywhere. | application, reviewer |
| user (for usager) | Meaningless where every actor is a user. | applicant |
| review (for avis) | Collides with the reviewer's own work. | opinion |
| attachment (for pièce justificative) | The ActiveStorage word; a PJ is a *kind* of attachment. | supporting document |
| accept / decline (for the decision) | Conference papers are accepted; invitations are declined. | approve / reject |
| processing (as a state name) | Vague; "processed" says nothing about the outcome. | under review, decided |
| démarche, dossier, avis, champ (in English copy) | Untranslated. | procedure, application, opinion, field |

### Code policy

1. **Core model names stay.** `Dossier`, `Procedure`, `ProcedureRevision`,
   `Champ`, `TypeDeChamp`, `Avis`, `Commentaire`, `Instructeur`,
   `Administrateur`, `Gestionnaire`, `Expert`, `Invite`, `GroupeInstructeur`,
   `Traitement`, `Attestation`, `Etablissement`, `Individual`, `Service`,
   `Zone` are tables with up to hundreds of millions of rows and the team's
   spoken vocabulary. They keep their names, and their table and column names
   are frozen. Their *English* name in this document is for UI copy and for
   the API.
2. **Everything around them is English.** New methods, attributes, concerns,
   jobs, mailers, routes, Stimulus controllers, components, specs. A new
   method on `Dossier` is `submitted?`, not `depose?`; a new job is
   `ExpireApplicationsJob`, not `ExpirerDossiersJob`. Existing French
   identifiers are renamed opportunistically, in refactoring commits, when the
   code around them is touched.
3. **Frozen values are data, not names.** AASM state values (`en_construction`,
   `publiee`…), enum values stored in columns, and `Traitement` events are
   stored in the database and exposed by API v2. They never change. The
   English name of a state is used for the *predicate* and the *copy*
   (`dossier.under_review?`, "Under review"), the French value stays in the
   column.
4. **GraphQL API v2 is frozen.** Every type, field, enum value and mutation in
   `app/graphql/schema.graphql` keeps its name for as long as v2 exists.
   Changing what a field returns is a breaking change for integrators. The
   English names below are the v3 vocabulary, from the API v3 design record.
5. **Namespaces are frozen until moved as a whole.** `manager/` (the super
   admin backoffice), `users/`, `instructeurs/`, `experts/`,
   `administrateurs/`, `gestionnaires/`.
6. **HTTP paths stay French.** URL segments are mostly French today
   (`/commencer/`, `/dossiers/`, `/procedures/`, `/annotations-privees`,
   `/repasser-en-construction`, `/corbeille`, `/preremplir/`) and stay that
   way for the foreseeable future: they are public, bookmarked, embedded in
   emails and in administrations' own documentation. New routes follow the
   existing French paths of their area; do not introduce an English segment
   next to French siblings. The Ruby side of a route is still English: a French path can point to an
   English action and helper (`post 'repasser-en-construction', to:
   'dossiers#request_changes', as: :request_changes`). Whether to add
   translated aliases or move every path to English is a separate decision,
   tracked in the open questions, and not something this glossary settles.

### UI copy policy

- French is the source language. The French column is what the product says;
  English copy translates the concept.
- One concept, one word, per audience. An applicant and a reviewer may read
  different words for the same fact (see "Dismissed" below); the same audience
  never reads two words for one fact.
- State labels are adjectives or past participles ("Submitted", "Under
  review"), actions are imperative verbs ("Start review"), and the two never
  share a word that would change meaning across the pair.

## Actors

| French | English (UI) | English (code) | Frozen | Status | Notes |
|---|---|---|---|---|---|
| usager | applicant | `applicant` | `users` table, `Users::` namespace, `config/routes/usager.rb`, `usager_submit_en_construction!` | settled | The account that owns the dossier. In code the account is a `User`; "applicant" names the *role*. Never "user" in copy. |
| instructeur | reviewer | `reviewer` (role), `Instructeur` (model) | `instructeurs` table, `Instructeurs::` namespace, `GroupeInstructeur`, v2 `GroupeInstructeur`, `groupeInstructeur*` mutations | settled | "Instructor" is the worst false friend in the current UI. Rejected: caseworker (welfare connotation in British English), examiner, assessor, case officer. |
| instruction (the activity) | review | `review` | `en_instruction` state, `passer_en_instruction`, `Traitement` events | settled | "Review" is what the reviewer does. Never "instruction". |
| expert | expert | `expert`, `Expert` | `experts` table, `Experts::` namespace | settled | Invited on one dossier to give an opinion. |
| administrateur | administrator | `administrator`, `Administrateur` (model) | `administrateurs` table, `Administrateurs::` namespace, v2 `demarcheAjouterAdministrateur` | settled | Creates and publishes procedures. "Admin" only where space is short. |
| gestionnaire | group manager | `group_manager`, `Gestionnaire` (model) | `gestionnaires` table, `Gestionnaires::` namespace | proposed | Manages a tree of administrator groups. Not "manager" alone: `manager/` is the super admin backoffice. Current copy says "admins group manager". |
| groupe gestionnaire | administrator group | `administrator_group`, `GroupeGestionnaire` (model) | `groupe_gestionnaires` table | proposed | Always qualified: the bare word "team" is reserved for groupe instructeur. |
| super admin | super admin | `super_admin`, `SuperAdmin` | `super_admins` table, `manager/` namespace (Administrate) | settled | The `manager/` namespace name is legacy; do not reuse "manager" for anything else. |
| invité | guest | `guest`, `Invite` (model) | `invites` table | settled | Invited by the applicant to view or edit one dossier. |
| demandeur | person or organisation concerned; **applicant details** for the identity block | `Individual`, `Etablissement` (models); `applicant_identity` for the block | `individuals`, `etablissements` tables; v2 `Demandeur`, `PersonnePhysique`, `PersonneMorale` | proposed | The person or organisation the dossier is *about*. Usually the applicant, unless filed on someone's behalf. API v3 drops the concept: identity lives in fields. |
| bénéficiaire (dossier déposé pour un tiers) | beneficiary | `beneficiary`, `for_tiers` (column) | `dossiers.for_tiers`, `mandataire_first_name`, `mandataire_last_name` | settled | The third party an applicant files for. |
| mandataire | representative | `representative` | `dossiers.mandataire_*` | settled | The applicant acting for a beneficiary. Never "agent". |
| personne physique / personne morale | individual / organisation | `individual` / `organisation` | v2 `PersonnePhysique`, `PersonneMorale`; `Procedure#for_individual` | settled | "Organisation" covers companies, associations and public bodies alike. |
| entreprise / établissement | company / establishment | `Entreprise`, `Etablissement` (models) | tables, `siret` field type | settled | An établissement is one SIRET site of a company (SIREN). Keep the distinction in copy. |
| administration (the deciding body) | administration | — | — | settled | The generic word for whoever runs the procedure, in applicant-facing copy ("the administration will answer…"). |

## Core objects

| French | English (UI) | English (code) | Frozen | Status | Notes |
|---|---|---|---|---|---|
| démarche / procédure | procedure | `Procedure` (model), `procedure` | `procedures` table; v2 `Demarche`, `demarche*` | settled | The product says "démarche" to the public and "procédure" in code. English has one word. A form *plus* workflow, routing and decision rules. |
| dossier | application | `Dossier` (model); `application` in new identifiers, GraphQL v3 `Application` | `dossiers` table (11.5 M rows); v2 `Dossier`, `dossier*` | settled | Correct from both sides: applicants submit applications, reviewers review them. Never "file". |
| numéro de dossier | application number | `number` | `dossiers.id` is the number shown; v2 `Dossier.number` | settled | Shown as "n° 12345". |
| révision | revision | `ProcedureRevision`, `revision` | `procedure_revisions` table; v2 `Revision` | settled | Each edit of a published procedure creates one; existing dossiers keep theirs until rebased. |
| brouillon de démarche (révision en cours) | draft revision | `draft_revision` | `procedures.draft_revision_id` | settled | |
| révision publiée | published revision | `published_revision` | `procedures.published_revision_id` | settled | |
| champ | field value, or just **field** when the definition is meant | `Champ` (model); `field` in new identifiers; GraphQL v3 `FieldValue` | `champs` table (about 1 B rows); v2 `Champ` | settled | A value on a dossier. |
| type de champ | field | `TypeDeChamp` (model); `field` in new identifiers; GraphQL v3 `Field` | `types_de_champ` table; v2 `ChampDescriptor`, `TypeDeChamp` enum | settled | A field's definition on a revision. UI says "field" for both; code distinguishes definition (`TypeDeChamp`) from value (`Champ`). |
| annotation privée | internal field | `internal_field`, `private` (column) | `types_de_champ.private`; v2 `annotations`, `dossierModifierAnnotation*` | settled | A field only reviewers see and fill. "Annotation" suggests comments on a document; "internal" says who sees it. |
| champ public | applicant field | `public` | `TypeDeChamp.public_only` scope | settled | Only when the contrast with internal fields matters; otherwise just "field". |
| avis | opinion | `Avis` (model); `opinion` in new identifiers | `avis` table; v2 `Avis` | settled | Advisory opinion requested from an expert. "Advice" is uncountable; "review" collides with the reviewer. |
| avis confidentiel | confidential opinion | `confidential` | `avis.confidentiel` | settled | |
| réponse (à un avis) | answer | `answer` | `avis.answer` | settled | |
| messagerie | messaging | `messaging`, `DossierMessagerieConcern` | | settled | The feature. |
| message / commentaire | message | `Commentaire` (model); `message` in new identifiers; v3 `Message` | `commentaires` table; v2 `Message`, `dossierEnvoyerMessage` | settled | Never "comment" in copy: it is a conversation with the applicant. |
| pièce justificative | supporting document | `supporting_document`; `piece_justificative` field type | `type_champ` value `piece_justificative`; v2 `PieceJustificativeChamp` | settled | Never "attachment", which is the storage layer. Plural: supporting documents. French UI: "pièce à joindre". |
| pièce jointe (generic) | attachment | `attachment` | ActiveStorage | settled | Any uploaded file, including message attachments and decision documents. |
| titre d'identité | identity document | `identity_document`; `titre_identite` field type | `type_champ` value `titre_identite`; v2 `TitreIdentiteChamp` | settled | Watermarked on upload. Current copy says "Identity title", which is wrong. |
| traitement (historique) | history | `Traitement` (model); `state_change` in new identifiers; v3 `StateChange` | `traitements` table; v2 `Traitement`, `TraitementEvent` | settled | One row per state change. |
| décision | decision | `decision`; v3 `Decision` | | settled | The terminal fact: outcome, date, reason, automatic or not. |
| motivation | reason | `reason`; `motivation` (column) | `dossiers.motivation`; v2 `motivation` argument | settled | The text explaining the decision. Never "motivation" in English copy. |
| justificatif de motivation / justificatif de décision | decision document | `decision_document`; `justificatif_motivation` (attachment) | `Dossier#justificatif_motivation` | settled | The file a reviewer attaches to a decision. |
| attestation | decision notice | `decision_notice`; `Attestation`, `AttestationTemplate` (models); v3 `DecisionNotice` | `attestations`, `attestation_templates` tables; v2 `attestation` | settled | The PDF generated from the procedure template when a decision is issued, for approval or rejection. Rejected: certificate (approval only). |
| modèle d'attestation | decision notice template | `decision_notice_template`, `AttestationTemplate` | | settled | |
| attestation de dépôt | submission receipt | `submission_receipt`; `attestation_depot` | `Dossier#attestation_depot_pdf` | settled | Proves the dossier was submitted. Not a decision notice. |
| accusé de réception | acknowledgement of receipt | `acknowledgement_of_receipt`; `accuse_reception` | `combined_declarative_accuse_reception?` | settled | The email confirming submission on a declarative procedure. |
| accusé de lecture | read acknowledgement | `read_acknowledgement`; `accuse_lecture` | `procedures.accuse_lecture`, `dossiers.accuse_lecture_agreement_at`, `ReadAgreementColumn` | settled | The applicant confirms having read the decision. |
| label | label | `Label` (model), `label` | `labels`, `dossier_labels` tables; v2 `Label`, `dossierAjouterLabel` | settled | Reviewer-side coloured tag on a dossier. Keep "label" (it is also the French UI word). Say "field label" when a form label is meant nearby. |
| libellé (d'une démarche) | title | `title`; `libelle` (column) | `procedures.libelle`; v2 `title` | settled | |
| libellé (d'un champ, d'une option) | label | `label`; `libelle` (column) | `types_de_champ.libelle`; v2 `label` | settled | The standard form word. Disambiguate as "field label" where a reviewer `Label` is on the same screen. |
| description (d'un champ) | description | `description` | | settled | |
| notice explicative | guidance document | `guidance_document`; `notice` | `procedures.notice` attachment | proposed | The PDF an administrator attaches to help applicants. |
| groupe instructeur | team | `team`; `GroupeInstructeur` (model); v3 `Team` | `groupe_instructeurs` table; v2 `GroupeInstructeur` | settled | The unit a dossier is routed to and worked by. The bare word "team" means this; any other group is qualified. |
| routage | routing | `routing`, `RoutingEngine`, `routing_rules` | `procedures.routing_enabled` | settled | |
| règle de routage | routing rule | `routing_rule` | `groupe_instructeurs.routing_rule` | settled | |
| réaffecter (un dossier) | reassign | `reassign` | routes `reaffecter`, `reaffectation`; v2 `dossierChangerGroupeInstructeur` | settled | Move a dossier to another team. |
| service (unité administrative) | agency | `Service` (model); `agency` in new identifiers; v3 `Agency` | `services` table; v2 `Service` | settled | "Service" sounds like a microservice; "department" collides with département. |
| type d'organisme | organisation type | `type_organisme` (enum) | `services.type_organisme` | settled | Values: central administration, association, local authority, educational institution, state operator, devolved state service, other. |
| zone | zone | `Zone` (model) | `zones` table | settled | A ministerial perimeter. Keep the word. |
| suivi / suivre | follow | `Follow` (model), `follow`, `unfollow` | `follows` table; v2 `dossierBasculeSuivi` | settled | A reviewer follows a dossier to get it in "Followed by me". |
| notification | notification | `DossierNotification`, `notification` | `dossier_notifications` table | settled | |
| étiquette / balise (dans un modèle) | tag | `tag`, `TagsSubstitutionConcern` | | settled | The `--nom--` placeholders in email and notice templates. Not a `Label`. |
| modèle d'e-mail | email template | `email_template`, `Emails::*` | `emails_*` tables | settled | |
| opération de masse | bulk action | `BatchOperation` (model); `bulk_action` in new identifiers | `batch_operations` table | settled | UI says "bulk action"; the model keeps its name. |
| export | export | `Export`, `ExportTemplate` | tables | settled | Formats: CSV, ODS, XLSX, ZIP, JSON. |
| archive | archive | `Archive` | `archives` table | settled | The monthly or full download of a procedure's dossiers. Distinct from *archiving* a dossier (below). |
| transfert (de dossier) | transfer | `DossierTransfer`, `transfer` | `dossier_transfers` table | settled | Handing a dossier to another applicant account. |
| jeton (API) | API token | `ApiToken`, `api_token` | `api_tokens` table, `Administrateurs::JetonsController` | settled | Never "jeton" in copy. |
| référentiel | reference dataset | `Referentiel` (model); `reference_dataset` in new identifiers | `referentiels` table; `referentiel` field type | proposed | An external API or CSV a field draws its values from. Current copy: "reference data", "external data to configure". |
| pré-remplissage | prefill | `prefill`, `PrefillChamps` | route `/preremplir/` | settled | |
| clonage | duplicate (UI), clone (code) | `clone`, `DossierCloneConcern`, `ProcedureCloneConcern` | v2 `demarcheCloner` | settled | The UI verb is "Duplicate"; code keeps `clone`. |
| rendez-vous | appointment | `Rdv`, `appointment` | `rdvs` table | settled | Via RDV Service Public. |

## Application lifecycle

### States

Stored in `dossiers.state`, exposed as v2 `DossierState`. Values are frozen.

| Value (frozen) | French (UI) | English (UI) | English (code) | v3 enum | Status | Notes |
|---|---|---|---|---|---|---|
| `brouillon` | brouillon | draft | `draft?` | `DRAFT` | settled | |
| `en_construction` | déposé, en attente d'examen | submitted | `submitted?` | `SUBMITTED` | settled | Deposited, visible to the administration, still editable by the applicant. Editability is a property, not the state's name. Current copy: "submitted, pending processing". |
| `en_instruction` | en cours d'instruction | under review | `under_review?` | `UNDER_REVIEW` | settled | Locked for the applicant. Never "processing" or "being instructed". |
| `accepte` | accepté | approved | `approved?` | `APPROVED` | settled | Administrative decisions are approved, not accepted. |
| `refuse` | refusé | rejected | `rejected?` | `REJECTED` | settled | Pairs with approved. Never "declined". |
| `sans_suite` | classé sans suite | dismissed (reviewer copy); closed without a decision (applicant copy) | `dismissed?` | `DISMISSED` | settled | A real decision meaning "we will not rule on the merits". "Dismissed" is exact for reviewers; applicants get the plain phrase. Current copy: "closed, no further action". |

State groups used in code:

| Code today | French | English (code) | Meaning |
|---|---|---|---|
| `Dossier::TERMINE`, `state_termine` | terminé, traité | `decided`, `decided?` | One of the three decisions. "Processed" is banned as a state name. |
| `Dossier::EN_CONSTRUCTION_OU_INSTRUCTION`, `en_cours` | en cours | `open`, `open?` | Submitted or under review. |
| `Dossier::SOUMIS` | soumis | `submitted_or_later` | Anything but draft. |
| `Dossier::INSTRUCTION_COMMENCEE` | instruction commencée | `review_started` | Under review or decided. |

### Events and actions

AASM event names, `Traitement` events and v2 mutation names are frozen.
English verbs name what the actor *does*, not the French state they reach.

| French action | AASM event (frozen) | `Traitement` event (frozen) | v2 mutation (frozen) | English (UI verb) | English (code) | Status | Notes |
|---|---|---|---|---|---|---|---|
| déposer | `passer_en_construction` | `depose` | — | Submit | `submit` | settled | "Submit" also names the applicant's button. `depose_at` → `submitted_at`. |
| passer en instruction | `passer_en_instruction` | `passe_en_instruction` | `dossierPasserEnInstruction` | Start review | `start_review` | settled | |
| passer automatiquement en instruction | `passer_automatiquement_en_instruction` | `passe_en_instruction_automatiquement` | — | (automatic) | `start_review_automatically` | settled | Declarative procedures. |
| repasser en construction / demander une correction | `repasser_en_construction` | `repasse_en_construction` | `dossierRepasserEnConstruction` | Request changes | `request_changes` | settled | Names the purpose: send it back for the applicant to fix. |
| demander à compléter | `repasser_en_construction_with_pending_correction` (reason `incomplete`) | `repasse_en_construction` | — | Request missing information | `request_completion` | proposed | A change request whose reason is "incomplete". |
| annuler la demande de correction | `resolve_pending_correction!` | — | `dossierAnnulerDemandeCorrection` | Cancel change request | `cancel_change_request` | settled | |
| accepter | `accepter` | `accepte` | `dossierAccepter` | Approve | `approve` | settled | |
| accepter automatiquement | `accepter_automatiquement` | `accepte_automatiquement` | — | (automatic) | `approve_automatically` | settled | SVA and declarative procedures. |
| refuser | `refuser` | `refuse` | `dossierRefuser` | Reject | `reject` | settled | |
| refuser automatiquement | `refuser_automatiquement` | `refuse_automatiquement` | — | (automatic) | `reject_automatically` | settled | SVR. |
| classer sans suite | `classer_sans_suite` | `classe_sans_suite` | `dossierClasserSansSuite` | Dismiss | `dismiss` | settled | |
| repasser en instruction | `repasser_en_instruction` | `repasse_en_instruction` | `dossierRepasserEnInstruction` | Reopen review | `reopen_review` | settled | Undoes a decision. |
| terminer (rendre une décision) | — (`can_terminer?`) | — | — | Decide | `decide`, `can_decide?` | settled | The generic word for the three decisions. |
| archiver / désarchiver | `archiver!` / `desarchiver!` | — | `dossierArchiver` / `dossierDesarchiver` | Archive / Unarchive | `archive` / `unarchive` | settled | Hides a decided dossier from the reviewer's default lists. |
| suivre / ne plus suivre | `follow` / `unfollow` | — | `dossierBasculeSuivi` | Follow / Unfollow | `follow` / `unfollow` | settled | Toggles are a poor primitive; v3 has two mutations. |
| changer de groupe instructeur | — | — | `dossierChangerGroupeInstructeur` | Reassign to a team | `assign_team` | settled | |
| envoyer un message | — | — | `dossierEnvoyerMessage` | Send message | `send_message` | settled | |
| demander un avis | `demander_un_avis!` | — | — | Request an opinion | `request_opinion` | settled | |
| rendre un avis | — | — | — | Give an opinion | `submit_opinion` | settled | |
| ajouter / retirer un label | — | — | `dossierAjouterLabel` / `dossierSupprimerLabel` | Add label / Remove label | `add_label` / `remove_label` | settled | |
| modifier une annotation | — | — | `dossierModifierAnnotation*` | Edit internal fields | `update_internal_fields` | settled | |
| transférer | — | — | — | Transfer | `transfer` | settled | To another applicant account. |
| inviter | — | — | — | Invite | `invite` | settled | A guest on the dossier. |
| supprimer (mettre à la corbeille) | `hide_and_keep_track!`, `discard_and_keep_track!` | — | — | Delete | `delete` (UI), `hide` (code, see retention) | settled | |
| restaurer | `restore` | — | — | Restore | `restore` | settled | |
| repousser l'expiration | `extend_conservation` | — | — | Extend retention | `extend_retention` | settled | |
| relancer (brouillon non déposé) | `notify_brouillon_not_submitted` | — | — | Remind | `remind` | settled | |
| rebaser | `rebase!` | — | — | (never shown) | `rebase` | settled | Moving a dossier to a newer revision. |

### Timestamps and durations

| French | English (UI) | English (code) | Frozen | Status | Notes |
|---|---|---|---|---|---|
| date de dépôt | submitted on | `submitted_at`; `depose_at` (column) | `dossiers.depose_at`; v2 `dateDepot` | settled | Set once, kept forever. |
| date de passage en instruction | review started on | `review_started_at`; `en_instruction_at` (column) | `dossiers.en_instruction_at`; v2 `datePassageEnInstruction` | settled | |
| date de décision / de traitement | decided on | `decided_at`; `processed_at` (column) | `dossiers.processed_at`; v2 `dateTraitement` | settled | |
| dernière modification | last modified | `updated_at`, `last_champ_updated_at` | | settled | |
| délai d'instruction / temps usuel de traitement | usual processing time | `usual_processing_time`; `usual_traitement_time` | `ProcedureStatsConcern#usual_traitement_time` | settled | "Processing" is fine for a *duration*; it is banned only as a state name. |
| durée de conservation | retention period | `retention_period`; `duree_conservation_dossiers_dans_ds` (column) | `procedures.duree_conservation_dossiers_dans_ds` | settled | |
| date d'expiration | expiry date | `expires_at`; `expired_at` (column) | `dossiers.expired_at` | settled | |
| date de décision SVA/SVR | automatic decision date | `automatic_decision_on`; `sva_svr_decision_on` (column) | `dossiers.sva_svr_decision_on` | settled | |

### Automatic decisions

| French | English (UI) | English (code) | Frozen | Status | Notes |
|---|---|---|---|---|---|
| silence vaut accord (SVA) | automatic approval | `automatic_approval`; `sva` (enum value) | `procedures.sva_svr` JSON column (`SVASVRConfiguration#decision`) | settled | Keep "SVA" as a parenthetical for French-law readers: "automatic approval (SVA)". |
| silence vaut rejet (SVR) | automatic rejection | `automatic_rejection`; `svr` (enum value) | same | settled | |
| démarche déclarative | declarative procedure | `declarative`, `declarative_with_state` | `procedures.declarative_with_state` | settled | Submission triggers review start or approval automatically. |

### Correction requests

| French | English (UI) | English (code) | Frozen | Status | Notes |
|---|---|---|---|---|---|
| demande de correction | change request | `ChangeRequest`; `DossierCorrection` (model) | `dossier_corrections` table; v2 `Correction`, `CorrectionReason` | settled | |
| en attente de correction / à corriger | changes requested | `changes_requested?`; `pending_correction?`, `A_CORRIGER` | `DossierCorrectableConcern` | settled | The applicant-side badge. |
| motif : incorrect / incomplet / obsolète | reason: incorrect / incomplete / outdated | `incorrect`, `incomplete`, `outdated` | `dossier_corrections.reason` | settled | |
| correction déposée | changes submitted | `changes_submitted` | `Traitement` `depose_correction_usager` | settled | |
| en attente de réponse | awaiting reply | `awaiting_reply?`; `DossierPendingResponse` | `dossier_pending_responses` table | settled | The applicant has not answered a message. |

### Reviewer lists

The tabs of a reviewer's procedure page. Stored as `Export#statut` values and
`ProcedurePresentation` filter names; those keys are frozen.

| Key (frozen) | French (UI) | English (UI) | English (code) | Status | Notes |
|---|---|---|---|---|---|
| `a-suivre` | à suivre | unassigned | `unassigned` | proposed | Open dossiers no reviewer follows yet. Current copy "To follow" is a literal translation. |
| `suivis` | suivis par moi | followed by me | `followed` | settled | |
| `traites` | traités | decided | `decided` | settled | Current copy "Processed". |
| `tous` | tous | all | `all` | settled | |
| `expirant` | expirant | expiring | `expiring` | settled | |
| `supprimes` / `supprimes_recemment` | corbeille | trash | `trash` | settled | |
| `archives` | à archiver | to archive | `archivable` | settled | |

## Retention and deletion

| French | English (UI) | English (code) | Frozen | Status | Notes |
|---|---|---|---|---|---|
| corbeille | trash | `trash` | routes `corbeille` | settled | Not "bin", not "recycle bin". |
| supprimer (par l'usager ou l'administration) | delete | `hidden_by_user_at`, `hidden_by_administration_at`, `hidden_by_reason` | `dossiers.hidden_by_*` columns | settled | UI says "delete"; the row is only hidden until expiry. Code says `hide` for the hidden step and `discard` for the Discard gem step. |
| supprimé définitivement | permanently deleted | `DeletedDossier` (model) | `deleted_dossiers` table; v2 `DeletedDossier` | settled | Only a deletion record remains. |
| motif de suppression | deletion reason | `reason` | `deleted_dossiers.reason`; v2 `DeletedDossierReason` | settled | Values: user request, procedure removed, expired, not modified for a long time. |
| expiration | expiry | `expiry`, `expired`, `expiring` | `dossiers.expired_at`, `hidden_by_expired_at` | settled | Noun "expiry", adjective "expiring". |
| conservation | retention | `retention` | see retention period above | settled | |
| repousser l'expiration / prolonger la conservation | extend retention | `extend_retention`; `conservation_extension` (column) | `dossiers.conservation_extension` | settled | |
| archivage (d'un dossier) | archiving | `archive`, `archived_at` | `dossiers.archived` | settled | Reviewer-side, reversible. Not deletion. |
| archivage automatique (d'une démarche) | automatic archiving | `auto_archive_on` | `procedures.auto_archive_on` | settled | Every submitted dossier starts review on that date. |
| brouillon non déposé | unsubmitted draft | `unsubmitted_draft` | `Cron::NotifyDraftNotSubmittedJob` | settled | |

## Procedure lifecycle

Stored in `procedures.aasm_state`, exposed as v2 `DemarcheState`. Values are frozen.

| Value (frozen) | French (UI) | English (UI) | English (code) | v3 enum | Status |
|---|---|---|---|---|---|
| `brouillon` | brouillon | draft | `brouillon?` (existing), `draft?` (new) | `DRAFT` | settled |
| `publiee` | publiée | published | `publiee?` (existing), `published?` (new) | `PUBLISHED` | settled |
| `close` | close | closed | `close?` (existing), `closed?` (new) | `CLOSED` | settled |
| `depubliee` | dépubliée | unpublished | `depubliee?` (existing), `unpublished?` (new) | `UNPUBLISHED` | settled |

| French action | AASM event (frozen) | v2 mutation (frozen) | English (UI) | English (code) | Status | Notes |
|---|---|---|---|---|---|---|
| publier | `publish` | `demarchePublier` | Publish | `publish` | settled | Already English in code. |
| publier une nouvelle révision | `publish_revision!` | — | Publish changes | `publish_revision` | settled | |
| clore | `close` | — | Close | `close` | settled | Route `fermeture` is legacy. |
| dépublier | `unpublish` | — | Unpublish | `unpublish` | settled | |
| réouvrir | `publish_or_reopen!` | — | Reopen | `reopen` | settled | |
| cloner | `clone` | `demarcheCloner` | Duplicate | `clone` | settled | |
| tester (démarche en test) | — | — | Test | `test` | settled | A draft procedure accepting test dossiers. |
| lien de la démarche / chemin | procedure link / URL path | `ProcedurePath`, `path` | `procedure_paths` table | settled | |
| motif de clôture | closing reason | `closing_reason` | `procedures.closing_reason` | settled | |
| cadre juridique | legal basis | `legal_basis`; `cadre_juridique` (column) | `procedures.cadre_juridique` | settled | |
| règles d'inéligibilité | eligibility rules | `eligibility_rules`; `ineligibilite_rules` (column) | `procedure_revisions.ineligibilite_rules` | settled | The English UI already says "Eligibility rules"; keep the positive form. |
| démarche pour un tiers | filing on behalf of someone | `for_tiers_enabled` | `procedures.for_tiers_enabled` | settled | |
| statistiques | statistics | `Users::StatistiquesController` | | settled | |

## Form model

| French | English (UI) | English (code) | Frozen | Status | Notes |
|---|---|---|---|---|---|
| formulaire | form | `form` | | settled | The set of fields of a revision. |
| titre de section | section | `section`; `header_section` (type) | `type_champ` value `header_section`; v2 `HeaderSectionChamp` | settled | Copy says "section"; the header itself is the section's title. |
| bloc répétable | repeatable block | `repeatable_block`; `repetition` (type) | `type_champ` value `repetition`; v2 `RepetitionChamp` | settled | Current copy "Repetition" is meaningless. |
| ligne (d'un bloc répétable) | row | `RepetitionRow`, `row` | v2 `Row` | settled | |
| explication | explanation | `explanation`; `explication` (type) | `type_champ` value `explication` | settled | |
| champ obligatoire | required field | `mandatory` (column) | `types_de_champ.mandatory` | settled | UI says "required", code keeps `mandatory`. |
| champ conditionnel / condition d'affichage | conditional field / display condition | `condition`, `Logic::*` | `types_de_champ.condition` | settled | |
| arbre des champs | field tree | `TypeDeChampTree`, `TypeDeChampNode` | `procedure_revisions.type_de_champ_tree` | settled | |
| colonne | column | `Column`, `Columns::*` | v2 `Column` | settled | A projection of a field into a filterable, exportable value. |
| valeur | value | `value` | `champs.value` | settled | |
| donnée externe | external data | `external_data`, `ChampExternalDataConcern` | `champs.external_state` | settled | Fetched from an API after the applicant fills a key (SIRET, RNA…). |

### Field types

The `type_champ` enum is frozen. The French column is the current French UI
label; the English column is the target label (current copy in the note where it
differs).

| Value (frozen) | French (UI) | English (UI) | Status | Notes |
|---|---|---|---|---|
| `header_section` | Titre de section | Section | settled | Current: "Header section". |
| `repetition` | Bloc répétable | Repeatable block | settled | Current: "Repetition". |
| `explication` | Explication | Explanation | settled | Current: "Explication". |
| `dossier_link` | Lien vers un autre dossier | Link to another application | settled | Current: "File link". |
| `engagement_juridique` | Engagement juridique | Legal commitment (Chorus) | settled | |
| `text` | Texte court | Short text | settled | |
| `textarea` | Texte long | Long text | settled | |
| `formatted` | Champ formaté | Formatted text | settled | |
| `number` | Nombre | Number | settled | Legacy type. |
| `integer_number` | Nombre entier | Whole number | proposed | Current: "Integer number". |
| `decimal_number` | Nombre décimal | Decimal number | settled | |
| `date` | Date | Date | settled | |
| `datetime` | Date et heure | Date and time | settled | |
| `checkbox` | Case à cocher seule | Checkbox | settled | |
| `yes_no` | Oui/Non | Yes / No | settled | |
| `drop_down_list` | Choix simple | Single choice | settled | Current: "Dropdown list". The rendering (dropdown or radio) is not the concept. |
| `multiple_drop_down_list` | Choix multiple | Multiple choice | settled | |
| `linked_drop_down_list` | Deux menus déroulants liés | Two linked lists | settled | |
| `piece_justificative` | Pièce à joindre | Supporting document | settled | |
| `titre_identite` | Titre identité | Identity document | settled | Current: "Identity title". |
| `civilite` | Civilité | Salutation | settled | Current: "Civility". |
| `email` | Adresse électronique | Email address | settled | |
| `phone` | Téléphone | Phone number | settled | |
| `address` | Adresse | Address | settled | Current: "Adress". |
| `iban` | Numéro IBAN | IBAN | settled | |
| `siret` | Numéro SIRET | SIRET number | settled | |
| `rna` | RNA (Répertoire national des associations) | RNA (association register number) | settled | |
| `rnf` | RNF (Répertoire national des fondations) | RNF (foundation register number) | settled | |
| `annuaire_education` | Établissement scolaire | School | settled | |
| `communes` | Commune française actuelle | Municipality | settled | The French label stays as is. |
| `departements` | Département | Département | settled | Keep the French word: "county" is wrong. |
| `regions` | Région | Region | settled | |
| `epci` | EPCI | EPCI (inter-municipal body) | settled | |
| `pays` | Pays | Country | settled | |
| `carte` | Carte | Map | settled | Current: "Card". |
| `cojo` | Accréditation Paris 2024 | Paris 2024 accreditation | settled | |
| `referentiel` | Référentiel configurable | Reference dataset | proposed | |
| `pre_rempli` | Pré-rempli | Prefilled | settled | |
| `quotient_familial` | Quotient familial | Family quotient | settled | API Particulier. |
| `etudiant_boursier` | Statut étudiant boursier | Student grant status | settled | |
| `aah` | Allocation adulte handicapé | Adult disability allowance (AAH) | settled | |
| `aeeh` | Allocation d'éducation de l'enfant handicapé | Disabled child education allowance (AEEH) | settled | |
| `ars` | Allocation de rentrée scolaire | Back-to-school allowance (ARS) | settled | |

## Identity and external services

| French | English (UI) | English (code) | Notes |
|---|---|---|---|
| FranceConnect | FranceConnect | `FranceConnect*` | Product name, never translated. |
| ProConnect (ex AgentConnect) | ProConnect | `ProConnect*` | Product name. |
| API Entreprise / API Particulier | API Entreprise / API Particulier | `ApiEntreprise*`, `ApiParticulier*` | Product names. |
| Annuaire du service public | public services directory | `AnnuaireServicePublicService` | |
| Chorus | Chorus | `ChorusConfiguration` | State accounting system. |
| RDV Service Public | RDV Service Public | `Rdv*` | Product name. |

## Frozen surfaces, in one place

- **Database**: every table and column named in a "Frozen" cell above, plus all
  `type_champ`, state and enum values.
- **GraphQL API v2**: `app/graphql/schema.graphql` in full. `Demarche`,
  `Dossier`, `Champ`, `ChampDescriptor`, `Avis`, `Traitement`,
  `GroupeInstructeur`, `Demandeur`, `PersonnePhysique`, `PersonneMorale`,
  `DossierState`, `DemarcheState`, and every `dossier*`, `demarche*`,
  `groupeInstructeur*` mutation.
- **HTTP paths**: every URL segment, French or not. `/commencer/`,
  `/preremplir/`, `/dossiers/`, `/procedures/`, `/avis/`, `/corbeille`,
  `/annotations-privees`, and every route an applicant, reviewer or
  administrator may have bookmarked, received by email or written into their
  own documentation. See rule 6 of the code policy.
- **Controller namespaces**: `users/`, `instructeurs/`, `experts/`,
  `administrateurs/`, `gestionnaires/`, `manager/`.
- **Email templates**: `Emails::Depose`, `Accepte`, `Refuse`, `ClasseSansSuite`,
  `PasseEnInstruction`, `RepasseEnInstruction`, and the tags administrators
  have written into their templates.

## Open questions

- **Demandeur** in copy: "applicant details" for the identity block works
  when applicant and demandeur coincide, which is the common case. The
  filing-for-a-beneficiary case needs its own copy. Revisit once the
  identity-in-fields work lands.
- **Integer number**: "Whole number" reads better for applicants but
  administrators may look for "integer". Decide when the field picker copy is
  reviewed.
- **Reference dataset** for référentiel: alternatives are "external list" and
  "lookup". Decide when the administrator UI for référentiels is next touched.
- **Unassigned** for "à suivre": it is the closest English for "nobody follows
  it yet", but a dossier in that tab *is* assigned to a team. "Not followed"
  is the literal alternative.
- **English HTTP paths**: French paths stay (code policy, rule 6). Whether the
  English UI should one day get translated path aliases (`/applications/` next
  to `/dossiers/`), or every path should move to English behind permanent
  redirects, is a product and infrastructure decision in its own right, with
  its own cost (redirects kept forever, emails and documentation in the wild).
  Not decided here.

## Changelog

- **2026-09-28** — First version. Actors, core objects, lifecycles, form
  model, field types, retention, frozen surfaces. API v3 vocabulary aligned
  with the API v3 design record (Reviewer, Team, Opinion, DecisionNotice,
  Field/FieldValue, Decision/StateChange).
