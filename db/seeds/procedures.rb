# frozen_string_literal: true

procedure = Procedure.new(
  libelle: "Démarche de démonstration",
  description: "Une démarche de démonstration avec les types de champ les plus courants.",
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

[
  { type: TypesDeChamp::Text.name, libelle: "Nom du projet", mandatory: true },
  { type: TypesDeChamp::Textarea.name, libelle: "Description du projet", mandatory: true },
  { type: TypesDeChamp::Date.name, libelle: "Date de début" },
  { type: TypesDeChamp::DropDownList.name, libelle: "Type de projet", drop_down_options: ["Association", "Entreprise", "Collectivité"] },
  { type: TypesDeChamp::Checkbox.name, libelle: "Le projet bénéficie d'un financement public" },
  { type: TypesDeChamp::PieceJustificative.name, libelle: "Justificatif" },
].reduce(nil) do |previous, params|
  type_de_champ = procedure.draft_revision.add_type_de_champ(**params, after_stable_id: previous&.stable_id)
  raise type_de_champ.errors.full_messages.to_sentence if type_de_champ.errors.any?
  type_de_champ
end

procedure.publish_or_reopen!(administrateurs.default, "demarche-demo")
instructeurs.default.assign_to_procedure(procedure)

procedures.label individual: procedure

# Procedures that went through their whole lifecycle: published, then closed
# (procedures.close) or unpublished (procedures.depubliee).
{ close: :close!, depubliee: :unpublish! }.each do |label, event|
  procedure = Procedure.new(
    libelle: "Démarche de démonstration (#{label})",
    description: "Une démarche de démonstration qui n’accepte plus de nouveaux dossiers.",
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

  procedure.publish_or_reopen!(administrateurs.default, "demarche-demo-#{label}")
  procedure.public_send(event)

  procedures.label(label => procedure)
end

brouillon_procedure = Procedure.new(
  libelle: "Démarche de démonstration (brouillon)",
  description: "Une démarche de démonstration encore en brouillon.",
  cadre_juridique: "https://www.legifrance.gouv.fr/",
  duree_conservation_dossiers_dans_ds: 3,
  max_duree_conservation_dossiers_dans_ds: Procedure::OLD_MAX_DUREE_CONSERVATION,
  administrateurs: [administrateurs.default],
  service: services.default
)
brouillon_procedure.draft_revision = brouillon_procedure.revisions.build
brouillon_procedure.save!

procedures.label brouillon: brouillon_procedure
