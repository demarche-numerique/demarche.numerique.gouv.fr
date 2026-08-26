# frozen_string_literal: true

# A published procedure for individuals routed to two groupes instructeurs
# ("défaut" and "deuxième groupe"), owned by the default administrateur.
# Load in a spec with `seed "cases/routage"`.

procedure = Procedure.new(
  libelle: "Démarche de démonstration (routage)",
  description: "Une démarche de démonstration routée vers plusieurs groupes d’instructeurs.",
  cadre_juridique: "https://www.legifrance.gouv.fr/",
  lien_site_web: "https://www.exemple.fr",
  duree_conservation_dossiers_dans_ds: 3,
  max_duree_conservation_dossiers_dans_ds: Procedure::OLD_MAX_DUREE_CONSERVATION,
  for_individual: true,
  administrateurs: [administrateurs.default],
  zones: [zones.default],
  service: services.default
)
procedure.draft_revision = procedure.revisions.build
procedure.save!

type_de_champ = procedure.draft_revision.add_type_de_champ(type: TypesDeChamp::Text.name, libelle: "Nom du projet", mandatory: true)
raise type_de_champ.errors.full_messages.to_sentence if type_de_champ.errors.any?

procedure.publish_or_reopen!(administrateurs.default, "demarche-demo-routage")
# No instructeur is assigned: specs about groupe management expect empty
# groupes, like the factory's :routee trait.
GroupeInstructeur.create!(label: "deuxième groupe", procedure:)
procedure.toggle_routing

procedures.label routee: procedure
