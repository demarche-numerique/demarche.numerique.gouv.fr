# frozen_string_literal: true

class Instructeurs::ProcedureSummaryComponent < ApplicationComponent
  with_collection_parameter :procedure

  delegate  :current_administrateur,
            :current_instructeur,
            :procedure_libelle_with_number,
            :procedure_badge,
            :external_link_attributes,
            to: :helpers

  attr_reader :procedure

  alias_method :p, :procedure

  def initialize(procedure:)
    @procedure = procedure
  end

  def placeholder_span
    "⋯"
  end
end
