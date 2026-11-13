# frozen_string_literal: true

class Columns::DossierLinkProcedureColumn < Columns::JSONPathColumn
  include Columns::DossierLinkProcedureLookup

  def initialize(procedure_id:, label:, stable_id:, tdc_type:, displayable:, mandatory:, limited_procedure_ids:)
    @limited_procedure_ids = limited_procedure_ids.presence

    super(
      procedure_id:,
      label:,
      stable_id:,
      tdc_type:,
      jsonpath: '$.procedure_id',
      displayable:,
      type: :enum,
      mandatory:
    )
  end

  def options_for_select
    @procedure_options ||= if @limited_procedure_ids
      options_for(@limited_procedure_ids)
    else
      options_for(observed_procedure_ids).sort_by { I18n.transliterate(it.first).downcase }
    end
  end

  def usable_in_conditions? = false

  def label_for_value(value)
    return super if value == NOT_FILLED_VALUE

    id = parse_id(value)

    return if id.nil?

    procedure_title(id) || I18n.t('activerecord.attributes.procedure_presentation.fields.dossier_link.deleted_procedure', id:)
  end

  private

  def options_for(ids)
    load_linked_procedures(ids)
    ids.map { [label_for_value(it.to_s), it.to_s] }
  end

  def sorted_dossiers(dossiers, order)
    direction = order == 'desc' ? 'DESC' : 'ASC'
    with_linked_procedure(dossiers).order(Arel.sql("linked_procedures.libelle #{direction}"), id: order)
  end

  def procedure_title(id)
    load_linked_procedures(@limited_procedure_ids) if !linked_procedures.key?(id) && @limited_procedure_ids

    linked_procedure(id)&.title
  end

  def observed_procedure_ids
    return [] if @procedure_id.nil?

    Rails.cache.fetch(['procedure', @procedure_id, 'dossier_link', stable_id, 'observed_procedure_ids'], expires_in: 5.minutes) do
      ChampData
        .where(stable_id:, stream: Dossier::MAIN_STREAM, dossier_id: observed_dossiers.select(:id))
        .distinct
        .pluck(Arel.sql("champs.value_json->>'procedure_id'"))
        .filter_map { parse_id(it) }
    end
  end

  def observed_dossiers
    Dossier
      .state_not_brouillon
      .where(for_procedure_preview: false, revision_id: ProcedureRevision.where(procedure_id: @procedure_id).select(:id))
  end

  def typed_value(champ) = super&.to_s

  def filtered_ids_for_values(dossiers, search_terms)
    ids = Array(search_terms).filter_map { parse_id(it) }

    return dossiers.ids if ids.empty?

    condition = %{champs.value_json @? '#{jsonpath_for_sql} ? (#{ids.map { "@ == #{it}" }.join(' || ')})'}

    targeted_dossiers(dossiers, condition).ids
  end
end
