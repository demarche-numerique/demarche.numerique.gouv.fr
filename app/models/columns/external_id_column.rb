# frozen_string_literal: true

# The identifier a champ stores next to its value: the code of an EPCI.
# Départements, régions and pays read their external_id through their
# canonical column already, communes through $.city_code.
class Columns::ExternalIdColumn < Columns::ChampColumn
  def initialize(procedure_id:, label:, stable_id:, tdc_type:, displayable: true, mandatory:)
    super(procedure_id:, label:, stable_id:, tdc_type:, column: :external_id, type: :text, displayable:, mandatory:)
  end

  def column_id = "#{super}.external_id"
end
