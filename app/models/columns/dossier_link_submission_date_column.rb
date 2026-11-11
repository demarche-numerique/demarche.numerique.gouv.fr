# frozen_string_literal: true

class Columns::DossierLinkSubmissionDateColumn < Columns::JSONPathColumn
  def initialize(procedure_id:, label:, stable_id:, tdc_type:, displayable:, mandatory:)
    super(procedure_id:, label:, stable_id:, tdc_type:, jsonpath: '$.submitted_on', displayable:, type: :date, mandatory:)
  end

  private

  def typed_value(champ) = super&.then { Date.iso8601(it) }

  def sorted_dossiers(dossiers, order)
    direction = order == 'desc' ? 'DESC' : 'ASC'
    dossiers.with_type_de_champ(stable_id).order(Arel.sql("champs.value_json->>'submitted_on' #{direction}"), id: order)
  end
end
