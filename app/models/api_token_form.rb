# frozen_string_literal: true

class APITokenForm
  include ActiveModel::Validations

  FIELDS = [:name, :api_token_to_duplicate, :target, :targets, :access, :networkFiltering, :networks, :lifetime, :customLifetime].freeze

  attr_reader :params, :administrateur

  validates :allowed_procedure_ids, presence: true, if: :custom_target?
  validate :networks_are_ip_addresses, if: :custom_networks?
  validates :expires_at, presence: true
  validates :expires_at, comparison: { greater_than_or_equal_to: -> (_) { Date.tomorrow }, less_than_or_equal_to: -> (_) { APIToken.max_expires_at } }, allow_nil: true

  def initialize(params, administrateur:)
    @params = params.permit(:name, :api_token_to_duplicate, :target, :access, :networkFiltering, :networks, :lifetime, :customLifetime, targets: [])
    @administrateur = administrateur
  end

  def self.from_token(token)
    new(ActionController::Parameters.new(
      api_token_to_duplicate: token.id,
      name: token.name,
      target: token.allowed_procedure_ids.blank? ? 'all' : 'custom',
      targets: token.allowed_procedure_ids,
      access: token.write_access? ? 'read_write' : 'read',
      networkFiltering: token.authorized_networks.blank? ? 'autoAssign' : 'customNetworks',
      networks: token.authorized_networks_for_ui.gsub(', ', ' ').presence
    ), administrateur: token.administrateur)
  end

  def name
    params[:name]
  end

  def targets
    Array(params[:targets])
  end

  def networks
    params[:networks]
  end

  def duplicating?
    params[:api_token_to_duplicate].present?
  end

  def custom_target? = params[:target] == 'custom'

  def custom_networks? = params[:networkFiltering] == 'customNetworks'

  def allowed_procedure_ids
    if custom_target?
      administrateur.procedure_ids.intersection(targets.map(&:to_i))
    end
  end

  def authorized_networks
    custom_networks? ? parsed_networks : []
  end

  def expires_at
    if params[:lifetime] == 'custom'
      begin
        Date.parse(params[:customLifetime].to_s)
      rescue Date::Error
        nil
      end
    else
      APIToken.selectable_lifetimes[params[:lifetime]&.to_sym]&.from_now&.to_date
    end
  end

  def token_attributes
    {
      name:,
      write_access: params[:access] == 'read_write',
      allowed_procedure_ids:,
      authorized_networks:,
      requires_ip_filtering: true,
    }
  end

  def to_h
    FIELDS.index_with { |field| params[field] }.compact
  end

  def hidden_fields_for(owned_fields)
    to_h.except(*owned_fields)
  end

  private

  def networks_are_ip_addresses
    errors.add(:networks, :invalid) if parsed_networks.include?(nil)
  end

  def parsed_networks = APIToken.parse_networks(networks)
end
