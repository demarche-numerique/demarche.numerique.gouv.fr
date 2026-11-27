# frozen_string_literal: true

class Columns::DossierLinkColumn < Columns::JSONPathColumn
  def options_for_dossiers(dossiers)
    return [] if type != :enum || @procedure_id.nil?

    ChampData
      .where(stable_id:, stream: Dossier::MAIN_STREAM, dossier_id: dossiers.merge(submitted_dossiers).select(:id))
      .distinct
      .pluck(json_value)
      .compact_blank
      .sort_by { I18n.transliterate(it).downcase }
      .map { [it, it] }
  end

  def usable_in_conditions? = false

  def label_for_value(value) = value

  private

  def submitted_dossiers
    Dossier.state_not_brouillon.where(for_procedure_preview: false, revision_id: ProcedureRevision.where(procedure_id: @procedure_id).select(:id))
  end

  def sorted_dossiers(dossiers, order)
    value_order = order == 'desc' ? json_value.desc : json_value.asc
    dossiers.with_type_de_champ(stable_id).order(value_order, id: order)
  end

  def filtered_ids_for_values(dossiers, search_terms)
    search_terms = Array(search_terms).compact_blank

    return dossiers.ids if search_terms.empty?

    dossiers.with_type_de_champ(stable_id).where(json_value.in(search_terms)).ids
  end

  def json_value
    Arel::Nodes::InfixOperation.new('->>', ChampData.arel_table[:value_json], Arel::Nodes.build_quoted(jsonpath.delete_prefix('$.')))
  end
end
