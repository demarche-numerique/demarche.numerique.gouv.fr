# frozen_string_literal: true

module Columns::DossierLinkProcedureLookup
  LinkedProcedure = Data.define(:title, :agency)

  def preload(champs)
    load_linked_procedures(champs.filter_map { linked_procedure_id(it) if it.stable_id == stable_id }.uniq)
  end

  private

  def parse_id(value) = Integer(value.to_s, 10, exception: false)

  def linked_procedure_id(champ) = parse_id(champ.value_json&.dig('procedure_id'))

  def linked_procedure(id)
    return if id.nil?

    load_linked_procedures([id]) if !linked_procedures.key?(id)
    linked_procedures[id]
  end

  def linked_procedures
    Current.dossier_link_procedures ||= {}
  end

  def load_linked_procedures(ids)
    missing_ids = ids.reject { linked_procedures.key?(it) }

    return if missing_ids.empty?

    found = Procedure.with_discarded
      .left_joins(:service)
      .where(id: missing_ids)
      .pluck(:id, :libelle, Arel.sql('COALESCE(services.nom, procedures.organisation)'))
      .to_h { |id, title, agency| [id, LinkedProcedure.new(title:, agency:)] }

    linked_procedures.merge!(missing_ids.index_with(nil), found)
  end

  def with_linked_procedure(dossiers)
    dossiers
      .with_type_de_champ(stable_id)
      .joins("LEFT OUTER JOIN procedures linked_procedures ON linked_procedures.id = (champs.value_json->>'procedure_id')::bigint")
  end
end
