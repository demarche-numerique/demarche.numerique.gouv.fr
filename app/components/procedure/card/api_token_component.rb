# frozen_string_literal: true

class Procedure::Card::APITokenComponent < ApplicationComponent
  API_TOKENS_AVAILABLE_COUNT = 2
  def initialize(procedure:)
    @procedure = procedure
  end

  def api_tokens_count_for_badge
    "#{api_tokens_count} / #{API_TOKENS_AVAILABLE_COUNT}"
  end

  def api_tokens_count
    [
      @procedure.specific_api_entreprise_token? || nil,
      @procedure.api_particulier_token? || nil,
    ].compact.size
  end
end
