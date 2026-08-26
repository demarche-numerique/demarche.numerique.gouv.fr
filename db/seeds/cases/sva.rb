# frozen_string_literal: true

# Published procedures configured for SVA / SVR decisions (silence vaut
# accord / rejet). Load in a spec with `seed "cases/sva"`.

["sva", "svr"].each do |decision|
  procedure = Procedure.new(
    libelle: "Démarche de démonstration (#{decision.upcase})",
    description: "Une démarche de démonstration en décision automatique #{decision.upcase}.",
    cadre_juridique: "https://www.legifrance.gouv.fr/",
    lien_site_web: "https://www.exemple.fr",
    duree_conservation_dossiers_dans_ds: 3,
    max_duree_conservation_dossiers_dans_ds: Procedure::OLD_MAX_DUREE_CONSERVATION,
    for_individual: true,
    administrateurs: [administrateurs.default],
    zones: [zones.default],
    service: services.default,
    sva_svr: SVASVRConfiguration.new(decision:).attributes
  )
  procedure.draft_revision = procedure.revisions.build
  procedure.save!

  type_de_champ = procedure.draft_revision.add_type_de_champ(type: TypesDeChamp::Text.name, libelle: "Nom du projet", mandatory: true)
  raise type_de_champ.errors.full_messages.to_sentence if type_de_champ.errors.any?

  procedure.publish_or_reopen!(administrateurs.default, "demarche-demo-#{decision}")
  instructeurs.default.assign_to_procedure(procedure)

  procedures.label(decision.to_sym => procedure)
end
