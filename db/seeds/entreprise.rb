# frozen_string_literal: true

# A published procedure for entreprises (for_individual: false) with two
# dossiers carrying a fully populated etablissement: one en_construction
# (avec_siret) and one en_instruction with populated champs
# (entreprise_en_instruction).

procedure = Procedure.new(
  libelle: "Démarche de démonstration (entreprises)",
  description: "Une démarche de démonstration réservée aux entreprises.",
  cadre_juridique: "https://www.legifrance.gouv.fr/",
  lien_site_web: "https://www.exemple.fr",
  duree_conservation_dossiers_dans_ds: 3,
  max_duree_conservation_dossiers_dans_ds: Procedure::OLD_MAX_DUREE_CONSERVATION,
  for_individual: false,
  administrateurs: [administrateurs.default],
  zones: [zones.default],
  service: services.default
)
procedure.draft_revision = procedure.revisions.build
procedure.save!

[
  { type: TypesDeChamp::Text.name, libelle: "Nom du projet", mandatory: true },
  { type: TypesDeChamp::Textarea.name, libelle: "Description du projet" },
].reduce(nil) do |previous, params|
  type_de_champ = procedure.draft_revision.add_type_de_champ(**params, after_stable_id: previous&.stable_id)
  raise type_de_champ.errors.full_messages.to_sentence if type_de_champ.errors.any?
  type_de_champ
end

procedure.publish_or_reopen!(administrateurs.default, "demarche-demo-entreprise")
instructeurs.default.assign_to_procedure(procedure)

procedures.label entreprise: procedure

build_etablissement = lambda do
  Etablissement.new(
    siret: "44011762001530",
    siege_social: true,
    naf: "4950Z",
    libelle_naf: "Transports par conduites",
    adresse: "GRTGAZ\r IMMEUBLE BORA\r 6 RUE RAOUL NORDLING\r 92270 BOIS COLOMBES\r",
    numero_voie: "6",
    type_voie: "RUE",
    nom_voie: "RAOUL NORDLING",
    complement_adresse: "IMMEUBLE BORA",
    code_postal: "92270",
    localite: "BOIS COLOMBES",
    code_insee_localite: "92009",
    entreprise_siren: "440117620",
    entreprise_capital_social: 537_100_000,
    entreprise_numero_tva_intracommunautaire: "FR27440117620",
    entreprise_forme_juridique: "SA à conseil d’administration (s.a.i.)",
    entreprise_forme_juridique_code: "5599",
    entreprise_nom_commercial: "GRTGAZ",
    entreprise_raison_sociale: "GRTGAZ",
    entreprise_siret_siege_social: "44011762001530",
    entreprise_code_effectif_entreprise: "51",
    entreprise_date_creation: Date.new(1990, 4, 24),
    entreprise_etat_administratif: :actif,
    entreprise_effectif_mensuel: 100.5,
    entreprise_effectif_mois: "03",
    entreprise_effectif_annee: "2020",
    diffusable_commercialement: true
  )
end

dossier = dossiers.create(
  :avec_siret,
  user: users.usager,
  revision: procedure.active_revision,
  groupe_instructeur: procedure.defaut_groupe_instructeur,
  autorisation_donnees: true,
  etablissement: build_etablissement.call
)
dossier.build_default_values
dossier.state = Dossier.states.fetch(:en_construction)
processed_at = DossierWithReferenceDate.assign(dossier, reference_date: 1.day.ago)
dossier.traitements.passer_en_construction(processed_at:)
dossier.submitted_revision_id = dossier.revision_id
dossier.save!

champ_values = {
  "Nom du projet" => "Rénovation du réseau de transport",
  "Description du projet" => "Un projet de rénovation du réseau de transport par conduites.",
}

dossier_en_instruction = dossiers.create(
  :entreprise_en_instruction,
  user: users.usager,
  revision: procedure.active_revision,
  groupe_instructeur: procedure.defaut_groupe_instructeur,
  autorisation_donnees: true,
  etablissement: build_etablissement.call
)
dossier_en_instruction.build_default_values
dossier_en_instruction.champ_data.each { it.value = champ_values.fetch(it.libelle, it.value) }
dossier_en_instruction.state = Dossier.states.fetch(:en_instruction)
processed_at = DossierWithReferenceDate.assign(dossier_en_instruction, reference_date: 1.day.ago)
dossier_en_instruction.traitements.passer_en_instruction(processed_at:)
dossier_en_instruction.submitted_revision_id = dossier_en_instruction.revision_id
dossier_en_instruction.save!
