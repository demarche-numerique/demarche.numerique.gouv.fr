# frozen_string_literal: true

class APITokenParams
  FIELDS = [:name, :api_token_to_duplicate, :target, :targets, :access, :networkFiltering, :networks, :lifetime, :customLifetime].freeze

  attr_reader :params

  def initialize(params)
    @params = params
  end

  def name
    params[:name]
  end

  def to_h
    FIELDS.index_with { |field| params[field] }.compact
  end

  def hidden_fields_for(owned_fields)
    to_h.except(*owned_fields)
  end
end
