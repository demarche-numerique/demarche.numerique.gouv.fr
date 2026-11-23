# frozen_string_literal: true

class APITokenForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :duplicated_token_id, :string
  attribute :target, :string
  attribute :procedure_ids, default: -> { [] }
  attribute :access, :string
  attribute :network_filtering, :string, default: 'autoAssign'
  attribute :networks, :string
  attribute :lifetime, :string
  attribute :custom_lifetime, :date

  attr_accessor :administrateur

  validates :name, presence: true
  validates :allowed_procedure_ids, presence: true, if: :custom_target?
  validate :networks_are_ip_addresses, if: :custom_networks?
  validates :expires_at, presence: true
  validates :expires_at, comparison: { greater_than_or_equal_to: -> (_) { Date.tomorrow }, less_than_or_equal_to: -> (_) { APIToken.max_expires_at } }, allow_nil: true

  def self.from_token(token)
    new(
      administrateur: token.administrateur,
      duplicated_token_id: token.id,
      name: token.name,
      target: token.full_access? ? 'all' : 'custom',
      procedure_ids: Array(token.allowed_procedure_ids),
      access: token.write_access? ? 'read_write' : 'read',
      network_filtering: token.authorized_networks.blank? ? 'autoAssign' : 'customNetworks',
      networks: token.authorized_networks_for_ui.gsub(', ', ' ').presence
    )
  end

  def duplicating? = duplicated_token_id.present?

  def custom_target? = target == 'custom'

  def custom_networks? = network_filtering == 'customNetworks'

  def allowed_procedure_ids
    if custom_target?
      administrateur.procedure_ids.intersection(procedure_ids.map(&:to_i))
    end
  end

  def authorized_networks
    custom_networks? ? parsed_networks : []
  end

  def expires_at
    if lifetime == 'custom'
      custom_lifetime
    else
      APIToken.selectable_lifetimes[lifetime&.to_sym]&.from_now&.to_date
    end
  end

  def token_attributes
    {
      name:,
      write_access: access == 'read_write',
      allowed_procedure_ids:,
      authorized_networks:,
      requires_ip_filtering: true,
    }
  end

  private

  def networks_are_ip_addresses
    errors.add(:networks, :invalid) if parsed_networks.include?(nil)
  end

  def parsed_networks = APIToken.parse_networks(networks)
end
