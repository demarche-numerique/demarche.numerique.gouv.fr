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

  def targets
    Array(params[:targets])
  end

  def duplicating?
    params[:api_token_to_duplicate].present?
  end

  def to_h
    FIELDS.index_with { |field| params[field] }.compact
  end

  def hidden_fields_for(owned_fields)
    to_h.except(*owned_fields)
  end

  def self.from_token(token)
    new(ActionController::Parameters.new(
      api_token_to_duplicate: token.id,
      name: token.name,
      target: token.allowed_procedure_ids.blank? ? 'all' : 'custom',
      targets: token.allowed_procedure_ids,
      access: token.write_access? ? 'read_write' : 'read',
      networkFiltering: token.authorized_networks.blank? ? 'autoAssign' : 'customNetworks',
      networks: token.authorized_networks.presence&.map { |ip| "#{ip}/#{ip.prefix}" }&.join(' ')
    ))
  end
end
