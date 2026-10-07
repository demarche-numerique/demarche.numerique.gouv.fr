# frozen_string_literal: true

# The default tabular export, the one an instructeur gets without picking an
# export template: the columns the export had before templates existed, under
# their historical headers, as an in-memory template so that the spreadsheet
# writers follow a single, column-based path (ExportTemplate being the other
# implementation of `dossier_exported_columns` / `columns_for_stable_id`).
#
# Most cells come from the procedure's column catalogue; the ones the catalogue
# would format differently go through a Columns::LegacyColumn, which is not
# resolvable through Procedure#find_column, so this template is never
# persisted.
class LegacyExportTemplate
  attr_reader :procedure, :kind

  # The csv, single-sheet, inlines the établissement columns that the xlsx
  # and ods exports put on their Etablissements sheet.
  ETABLISSEMENT_CSV_COLUMNS = [
    ['Établissement SIRET', 'siret', :text],
    ['Établissement siège social', 'siege_social', :boolean],
    ['Établissement NAF', 'naf', :text],
    ['Établissement libellé NAF', 'libelle_naf', :text],
    ['Établissement Adresse', 'adresse', :text],
    ['Établissement numero voie', 'numero_voie', :text],
    ['Établissement type voie', 'type_voie', :text],
    ['Établissement nom voie', 'nom_voie', :text],
    ['Établissement complément adresse', 'complement_adresse', :text],
    ['Établissement code postal', 'code_postal', :text],
    ['Établissement localité', 'localite', :text],
    ['Établissement code INSEE localité', 'code_insee_localite', :text],
    ['Entreprise SIREN', 'entreprise_siren', :text],
    ['Entreprise capital social', 'entreprise_capital_social', :integer],
    ['Entreprise numero TVA intracommunautaire', 'entreprise_numero_tva_intracommunautaire', :text],
    ['Entreprise forme juridique', 'entreprise_forme_juridique', :text],
    ['Entreprise forme juridique code', 'entreprise_forme_juridique_code', :text],
    ['Entreprise nom commercial', 'entreprise_nom_commercial', :text],
    ['Entreprise raison sociale', 'entreprise_raison_sociale', :text],
    ['Entreprise SIRET siège social', 'entreprise_siret_siege_social', :text],
    ['Entreprise code effectif entreprise', 'entreprise_code_effectif_entreprise', :text],
    ['Entreprise date de création', 'entreprise_date_creation', :date],
    ['Entreprise état administratif', 'entreprise_etat_administratif', :text],
    ['Entreprise nom', 'entreprise_nom', :text],
    ['Entreprise prénom', 'entreprise_prenom', :text],
    ['Association RNA', 'association_rna', :text],
    ['Association titre', 'association_titre', :text],
    ['Association objet', 'association_objet', :text],
    ['Association date de création', 'association_date_creation', :text],
    ['Association date de déclaration', 'association_date_declaration', :text],
    ['Association date de publication', 'association_date_publication', :text],
  ].freeze

  # kind: :csv, :xlsx or :ods
  def initialize(procedure:, kind:)
    @procedure = procedure
    @kind = kind
  end

  # Exports are tagged in Sentry with their template id; this one has none.
  def id = nil

  def dossier_exported_columns
    @dossier_exported_columns ||= dossier_columns.map { |(libelle, column)| ExportedColumn.new(column:, libelle:) }
  end

  def columns_for_stable_id(stable_id)
    champ_exported_columns_by_stable_id.fetch(stable_id, [])
  end

  private

  def champ_exported_columns_by_stable_id
    @champ_exported_columns_by_stable_id ||= exportable_type_de_champs.to_h do |type_de_champ|
      exported_columns = type_de_champ.legacy_export_columns(procedure_id: procedure.id).map do |(libelle, column)|
        ExportedColumn.new(column:, libelle:)
      end
      [type_de_champ.stable_id, exported_columns]
    end
  end

  # The root types de champ of the Dossiers sheet and the children of the
  # repetitions for their own sheets: the ones the writers iterate over.
  def exportable_type_de_champs
    children = procedure.all_revisions_type_de_champs.repetition.flat_map do |repetition|
      procedure.all_revisions_type_de_champs(parent: repetition).to_a
    end

    procedure.type_de_champs_for_procedure_export.to_a + children
  end

  def dossier_columns
    columns = [
      legacy_column('ID', 'id'),
      column('Email', 'self', 'user_email_for_display'),
      legacy_column('FranceConnect ?', 'user_from_france_connect?'),
    ]

    if procedure.for_individual?
      columns += [
        column('Civilité', 'individual', 'gender'),
        column('Nom', 'individual', 'nom'),
        column('Prénom', 'individual', 'prenom'),
        legacy_column('Dépôt pour un tiers', 'for_tiers'),
        column('Nom du mandataire', 'self', 'mandataire_last_name'),
        column('Prénom du mandataire', 'self', 'mandataire_first_name'),
      ]
      if procedure.ask_birthday
        columns << column('Date de naissance', 'individual', 'birthdate', type: :date)
      end
    elsif kind == :csv
      columns += ETABLISSEMENT_CSV_COLUMNS.map { |(libelle, name, type)| column(libelle, 'etablissement', name, type:) }
    else
      columns << column('Entreprise raison sociale', 'etablissement', 'entreprise_raison_sociale')
    end

    if procedure.chorusable? && procedure.chorus_configuration.complete?
      columns += [
        column('Domaine Fonctionnel', 'procedure', 'domaine_fonctionnel'),
        column('Référentiel De Programmation', 'procedure', 'referentiel_prog'),
        column('Centre De Coût', 'procedure', 'centre_de_cout'),
      ]
    end

    columns += [
      legacy_column('À archiver', 'archived'),
      column('État du dossier', 'self', 'state', type: :enum, options_for_select: state_options),
      column('Dernière mise à jour le', 'self', 'updated_at', type: :datetime),
      column('Dernière mise à jour du dossier le', 'self', 'last_champ_updated_at', type: :datetime),
      column('Déposé le', 'self', 'depose_at', type: :datetime),
      column('Passé en instruction le', 'self', 'en_instruction_at', type: :datetime),
    ]
    if procedure.sva_svr_enabled?
      columns << column("Date décision #{procedure.sva_svr_configuration.human_decision}", 'self', 'sva_svr_decision_on', type: :date)
    end
    columns += [
      column('Traité le', 'self', 'processed_at', type: :datetime),
      column('Motivation de la décision', 'self', 'motivation'),
      column('Instructeurs', 'followers_instructeurs', 'email'),
    ]
    if procedure.routing_enabled?
      columns << column('Groupe instructeur', 'groupe_instructeur', 'id')
    end

    columns
  end

  def column(libelle, table, name, type: :text, options_for_select: [])
    [libelle, Columns::DossierColumn.new(procedure_id: procedure.id, table:, column: name, label: libelle, type:, options_for_select:)]
  end

  # The historical export passed the id and the booleans untyped, so they
  # came out as text ("123", "true") rather than as number or boolean cells.
  def legacy_column(libelle, name)
    column = Columns::DossierColumn.new(procedure_id: procedure.id, table: 'self', column: name, label: libelle)
    [libelle, Columns::LegacyColumn.new(procedure_id: procedure.id, columns: column, label: libelle, &:to_s)]
  end

  # The historical labels ("Brouillon", "En construction"…), including the
  # states the instructeur filters leave out.
  def state_options
    Dossier.states.keys.map { [Dossier.human_attribute_name("state.#{it}"), it] }
  end
end
