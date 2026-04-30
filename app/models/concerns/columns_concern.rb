# frozen_string_literal: true

module ColumnsConcern
  extend ActiveSupport::Concern

  # we cannot use column.id ( == { procedure_id, column_id }.to_json)
  # as the order of the keys is not guaranteed
  # instead, we are using h_id == { procedure_id:, column_id: }
  # another way to find a column is to look for its label
  def find_column(h_id: nil, label: nil)
    column = columns.find { _1.h_id == h_id } if h_id.present?
    column = columns.find { _1.label == label } if label.present?

    # TODO: to remove after linked_drop_down column column_id migration
    if column.nil? && h_id.is_a?(Hash) && h_id[:column_id].present?
      new_column_id = h_id[:column_id]
        .gsub('->', '.')
        .gsub('departement_code', 'department_code')
        .gsub('naf', 'code_naf')

      h_id[:column_id] = new_column_id

      column = columns.find { _1.h_id == h_id }
    end

    raise ActiveRecord::RecordNotFound.new("Column: unable to find h_id: #{h_id} or label: #{label} for procedure_id #{id}") if column.nil?

    column
  end

  def columns
    Current.procedure_columns ||= {}

    Current.procedure_columns[id] ||= begin
      columns = dossier_columns
      columns.concat(standard_columns)
      columns.concat(individual_columns) if for_individual
      columns.concat(moral_columns) if !for_individual
      columns.concat(procedure_chorus_columns) if chorusable? && chorus_configuration.complete?
      columns.concat(types_de_champ_columns)
    end
  end

  def usager_columns_for_export
    columns = [dossier_id_column, user_email_for_display_column, user_france_connected_column]
    columns.concat(individual_columns) if for_individual
    columns.concat(moral_columns) if !for_individual
    columns.concat(procedure_chorus_columns) if chorusable? && chorus_configuration.complete?

    # ensure the columns exist in main list
    # otherwise, they will be found by the find_column method
    columns.filter { _1.id.in?(self.columns.map(&:id)) }
  end

  def dossier_columns_for_export
    columns = [dossier_state_column, dossier_archived_column]
    columns.concat(dossier_dates_columns)
    columns.concat([dossier_motivation_column])
    columns.concat(sva_svr_columns(for_export: true)) if sva_svr_enabled?
    columns.concat([dossier_accuse_lecture_agreement_at_column]) if accuse_lecture?
    columns.concat([groupe_instructeurs_id_column, followers_instructeurs_email_column])
    columns.concat([dossier_labels_column])

    # ensure the columns exist in main list
    # otherwise, they will be found by the find_column method
    columns.filter { _1.id.in?(self.columns.map(&:id)) }
  end

  def dossier_id_column = dossier_col(table: 'self', column: 'id', type: :integer)

  def dossier_state_column
    options_for_select = I18n.t('instructeurs.dossiers.filterable_state').map(&:to_a).map(&:reverse)

    dossier_col(table: 'self', column: 'state', type: :enum, options_for_select:, displayable: false)
  end

  def notifications_column = dossier_col(table: 'notifications', column: 'notifications', label: "notifications", filterable: false, displayable: false)

  def dossier_notifications_column
    options_for_select = I18n.t('instructeurs.dossiers.filterable_notification').map(&:to_a).map(&:reverse)

    dossier_col(table: 'dossier_notifications', column: 'notification_type', type: :enum, options_for_select:, displayable: false)
  end

  def sva_svr_columns(for_export: false)
    scope = [:activerecord, :attributes, :procedure_presentation, :fields, :self]

    columns = [
      dossier_col(table: 'self', column: 'sva_svr_decision_on', type: :date,
                label: I18n.t("#{sva_svr_decision}_decision_on", scope:, type: sva_svr_configuration.human_decision)),
    ]
    if !for_export
      columns << dossier_col(table: 'self', column: 'sva_svr_decision_before', type: :date, displayable: false,
                    label: I18n.t("#{sva_svr_decision}_decision_before", scope:))
    end
    columns
  end

  def default_sorted_column
    SortedColumn.new(column: notifications_column, order: 'desc')
  end

  def default_displayed_columns = [email_column]

  def dossier_filterable_columns
    dossier_columns
      .concat([dossier_labels_column])
      .concat([dossier_notifications_column])
      .filter(&:filterable)
  end

  def instructeurs_filterable_columns
    Array([groupe_instructeurs_id_column, followers_instructeurs_email_column]).filter(&:filterable)
  end

  def usager_filterable_columns
    columns = []
    if for_individual?
      columns.concat(individual_columns)
    else
      columns.concat(moral_columns)
    end
    columns.concat([email_column])
    columns.filter(&:filterable)
  end

  def form_filterable_columns
    all_revisions_types_de_champ.public_only.flat_map { _1.columns(procedure: self) }.filter(&:filterable)
  end

  def annotation_privees_filterable_columns
    all_revisions_types_de_champ.private_only.flat_map { _1.columns(procedure: self) }.filter(&:filterable)
  end

  private

  def groupe_instructeurs_id_column = dossier_col(table: 'groupe_instructeur', column: 'id', type: :enum)

  def followers_instructeurs_email_column = dossier_col(table: 'followers_instructeurs', column: 'email')

  def dossier_archived_column = dossier_col(table: 'self', column: 'archived', type: :boolean, displayable: false, filterable: false);

  def dossier_motivation_column = dossier_col(table: 'self', column: 'motivation', type: :text, displayable: false, filterable: false);

  def user_email_for_display_column = dossier_col(table: 'self', column: 'user_email_for_display', filterable: false, displayable: false)

  def user_france_connected_column = dossier_col(table: 'self', column: 'user_from_france_connect?', type: :boolean, filterable: false, displayable: false)

  def dossier_labels_column = dossier_col(table: 'dossier_labels', column: 'label_id', type: :enum, options_for_select: labels.map { [_1.name, _1.id] })

  def traitements_email_column = dossier_col(table: 'traitements', column: 'instructeur_email', filterable: true, displayable: false)

  def procedure_chorus_columns
    ['domaine_fonctionnel', 'referentiel_prog', 'centre_de_cout']
      .map { |column| dossier_col(table: 'procedure', column:, displayable: false, filterable: false) }
  end

  def dossier_non_displayable_dates_columns
    ['updated_since', 'depose_since', 'en_construction_since', 'en_instruction_since', 'processed_since']
      .map { |column| dossier_col(table: 'self', column:, type: :date, displayable: false, filterable: false) }
  end

  def dossier_dates_columns
    ['created_at', 'updated_at', 'last_champ_updated_at', 'depose_at', 'en_construction_at', 'en_instruction_at', 'processed_at', 'expired_at']
      .map { |column| dossier_col(table: 'self', column:, type: :datetime) }
  end

  def dossier_accuse_lecture_agreement_at_column = dossier_col(table: 'self', column: 'accuse_lecture_agreement_at', type: :date, filterable: false)

  def email_column
    dossier_col(table: 'user', column: 'email')
  end

  def dossier_columns
    columns = [dossier_id_column, notifications_column]
    columns.concat([dossier_state_column])
    columns.concat([dossier_archived_column])
    columns.concat(dossier_dates_columns)
    columns.concat([dossier_motivation_column])
    columns.concat([dossier_accuse_lecture_agreement_at_column]) if accuse_lecture?
    columns.concat(sva_svr_columns(for_export: false)) if sva_svr_enabled?
    columns.concat(dossier_non_displayable_dates_columns)
    columns.concat([Columns::ReadAgreementColumn.new(procedure_id: id)]) if accuse_lecture?
    columns
  end

  def standard_columns
    [
      email_column,
      user_email_for_display_column,
      followers_instructeurs_email_column,
      groupe_instructeurs_id_column,
      dossier_col(table: 'avis', column: 'question_answer', filterable: false),
      user_france_connected_column,
      dossier_labels_column,
      dossier_notifications_column,
      traitements_email_column,
    ]
  end

  def individual_columns
    @individual_columns = []

    @individual_columns << dossier_col(
      table: 'individual',
      column: 'gender',
      type: :enum,
      options_for_select: [
        [Individual::GENDER_FEMALE, Individual::GENDER_FEMALE],
        [Individual::GENDER_MALE, Individual::GENDER_MALE],
      ]
    ) unless self.no_gender?

    @individual_columns
      .concat ['nom', 'prenom'].map { |column| dossier_col(table: 'individual', column:) }
      .concat ['mandataire_last_name', 'mandataire_first_name'].map { |column| dossier_col(table: 'self', column:) }
      .concat ['for_tiers', 'submitted_with_france_connect'].map { |column| dossier_col(table: 'self', column:, type: :boolean, options_for_select: Champs::YesNoChamp.options) }
  end

  def moral_columns
    siret_column = dossier_col(table: 'etablissement', column: :siret)

    etablissements = Etablissement::DISPLAYABLE_COLUMNS.map do |(column, attributes)|
      dossier_col(table: 'etablissement', column:, type: attributes[:type], filterable: attributes.fetch(:filterable, true))
    end

    others = %w[code_postal].map { |column| dossier_col(table: 'etablissement', column:) }

    for_export = Etablissement::EXPORTABLE_ETABLISSEMENT_COLUMNS.map { |(column, attributes)| dossier_col(table: 'etablissement', column:, type: attributes[:type]) }
    for_export += Etablissement::EXPORTABLE_ASSOCIATION_COLUMNS.map { |(column, attributes)| dossier_col(table: 'etablissement', column:, type: attributes[:type]) }

    [siret_column, etablissements, others, for_export].flatten
  end

  def types_de_champ_columns
    all_revisions_types_de_champ.flat_map { _1.columns(procedure: self) }
  end

  def dossier_col(**args) = Columns::DossierColumn.new(**(args.merge(procedure_id: id)))
end
