# frozen_string_literal: true

# A draft procedure carrying one champ of every type (public) and one
# annotation of every type (private), mirroring the factory traits
# :with_all_champs / :with_all_annotations (same libelles: the type name,
# except drop_down_list which is labeled simple_drop_down_list). The
# repetition has two children, and a brouillon dossier is seeded with its
# default champs. Load in a spec with `seed "cases/champs"`.

ActiveRecord::Base.transaction do
  procedure = Procedure.new(
    libelle: "Démarche avec tous les types de champ",
    description: "Une démarche de démonstration avec un champ de chaque type.",
    cadre_juridique: "https://www.legifrance.gouv.fr/",
    duree_conservation_dossiers_dans_ds: 3,
    max_duree_conservation_dossiers_dans_ds: Procedure::OLD_MAX_DUREE_CONSERVATION,
    for_individual: true,
    administrateurs: [administrateurs.default],
    service: services.default
  )
  procedure.draft_revision = procedure.revisions.build
  procedure.save!
  instructeurs.default.assign_to_procedure(procedure)

  # .beta.gouv.fr domains must be explicitly allowed via
  # ALLOWED_API_DOMAINS_FROM_FRONTEND; plain .gouv.fr domains always are.
  referentiel_domain = ENV.fetch("ALLOWED_API_DOMAINS_FROM_FRONTEND", "").split(",").grep(/rnb-api.beta.gouv/).first || "https://rnb-api.data.gouv.fr"
  referentiel = Referentiels::APIReferentiel.create!(
    mode: "exact_match",
    url_tiptap: {
      "type" => "doc",
      "content" => [
        {
          "type" => "paragraph",
          "content" => [
            { "type" => "text", "text" => "#{referentiel_domain}/api/alpha/buildings/" },
            { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Valeur saisie par l'usager" } },
          ],
        },
      ],
    },
    test_data_tiptap: { "{query}" => "PG46YY6YWCX8" }
  )

  extra_params_by_class = {
    TypesDeChamp::DropDownList => { libelle: "simple_drop_down_list", drop_down_options: ["val1", "val2", "val3"] },
    TypesDeChamp::MultipleDropDownList => { drop_down_options: ["val1", "val2", "val3"] },
    TypesDeChamp::LinkedDropDownList => { drop_down_options: ["--primary--", "secondary"] },
    TypesDeChamp::Referentiel => { referentiel:, mandatory: true },
  }

  # Build all coordinates in memory and save the revision once: one champ of
  # every type per list, faster than one add_type_de_champ call per champ.
  revision = procedure.draft_revision

  build_type_de_champ = lambda do |klass, params, private_champ, position|
    type_de_champ = klass.new(private: private_champ, libelle: klass.type_champ, **params)
    revision.revision_type_de_champs.build(type_de_champ:, position:)

    if type_de_champ.is_a?(TypesDeChamp::PieceJustificative) && type_de_champ.nature.blank?
      type_de_champ.piece_justificative_template.attach(
        io: StringIO.new("toto"),
        filename: "toto.txt",
        content_type: "text/plain",
        metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
      )
    end
  end

  [false, true].each do |private_champ|
    TypeDeChamp.type_champ_classes.each.with_index do |klass, position|
      build_type_de_champ.call(klass, extra_params_by_class.fetch(klass, {}), private_champ, position)
    end
  end

  # titre_identite is a piece_justificative nature, not a type
  build_type_de_champ.call(
    TypesDeChamp::PieceJustificative,
    { nature: "titre_identite", libelle: "titre_identité" },
    false,
    TypeDeChamp.type_champ_classes.size
  )

  revision.save!

  repetition_coordinate = revision.revision_type_de_champs.find { it.type_de_champ.repetition? && !it.type_de_champ.private? }
  [
    [TypesDeChamp::Text, { libelle: "sub type de champ" }],
    [TypesDeChamp::IntegerNumber, { libelle: "sub type de champ2" }],
  ].each_with_index do |(klass, params), position|
    revision.revision_type_de_champs.create!(type_de_champ: klass.create!(params), parent: repetition_coordinate, position:)
  end

  procedures.label tous_champs: procedure

  dossier = dossiers.create(
    :tous_champs,
    user: users.usager,
    revision: procedure.active_revision,
    groupe_instructeur: procedure.defaut_groupe_instructeur,
    individual: Individual.new(gender: "Mme", nom: "Dupont", prenom: "Jeanne", birthdate: Date.new(1985, 3, 12)),
    autorisation_donnees: true
  )
  dossier.build_default_values
end
