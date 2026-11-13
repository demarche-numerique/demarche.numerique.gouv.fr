# frozen_string_literal: true

class Columns::DossierLinkProcedureAgencyColumn < Columns::ChampColumn
  include Columns::DossierLinkProcedureLookup

  def initialize(procedure_id:, label:, stable_id:, tdc_type:, displayable:, mandatory:)
    super(procedure_id:, label:, stable_id:, tdc_type:, displayable:, filterable: false, type: :text, mandatory:)
  end

  def column_id = "#{super}.procedure_agency"

  private

  def typed_value(champ) = linked_procedure(linked_procedure_id(champ))&.agency.presence

  def sorted_dossiers(dossiers, order)
    direction = order == 'desc' ? 'DESC' : 'ASC'
    with_linked_procedure(dossiers)
      .joins('LEFT OUTER JOIN services linked_services ON linked_services.id = linked_procedures.service_id')
      .order(Arel.sql("NULLIF(COALESCE(linked_services.nom, linked_procedures.organisation), '') #{direction}"), id: order)
  end
end
