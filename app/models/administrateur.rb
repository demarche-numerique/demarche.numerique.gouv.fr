# frozen_string_literal: true

class Administrateur < ApplicationRecord
  include UserFindByConcern
  UNUSED_ADMIN_THRESHOLD = ENV.fetch('UNUSED_ADMIN_THRESHOLD') { 6 }.to_i.months

  has_and_belongs_to_many :instructeurs
  has_many :administrateurs_procedures
  has_many :procedures, through: :administrateurs_procedures
  has_many :services
  has_many :api_tokens, inverse_of: :administrateur, dependent: :destroy
  has_many :commentaire_groupe_gestionnaires, as: :sender
  has_and_belongs_to_many :default_zones, class_name: 'Zone', join_table: 'default_zones_administrateurs'
  has_many :archives, as: :user_profile, dependent: :destroy
  has_many :exports, as: :user_profile, dependent: :destroy
  belongs_to :user
  belongs_to :groupe_gestionnaire, optional: true

  validates :user_id, uniqueness: true

  default_scope { eager_load(:user) }

  scope :inactive, -> { joins(:user).where(users: { last_sign_in_at: nil }) }
  scope :with_publiees_ou_closes, -> { joins(:procedures).where(procedures: { aasm_state: [:publiee, :close, :depubliee] }) }

  scope :unused, -> do
    joins(:user)
      .where.missing(:services)
      .left_outer_joins(:administrateurs_procedures) # needed to bypass procedure hidden default scope
      .where(administrateurs_procedures: { procedure_id: nil })
      .includes(:api_tokens)
      .where(users: { last_sign_in_at: ..UNUSED_ADMIN_THRESHOLD.ago })
      .merge(APIToken.where(last_v1_authenticated_at: nil).or(APIToken.where(last_v1_authenticated_at: ..UNUSED_ADMIN_THRESHOLD.ago)))
      .merge(APIToken.where(last_v2_authenticated_at: nil).or(APIToken.where(last_v2_authenticated_at: ..UNUSED_ADMIN_THRESHOLD.ago)))
  end

  delegate :rdv_connection, to: :instructeur
  delegate :email, :active?, to: :user, allow_nil: true

  def self.find_inactive_by_token(reset_password_token)
    self.inactive.with_reset_password_token(reset_password_token)
  end

  def self.find_inactive_by_id(id)
    self.inactive.find(id)
  end

  def registration_state
    if user.active?
      'Actif'
    elsif pro_connect_required? || user.reset_password_period_valid?
      'En attente'
    else
      'Expiré'
    end
  end

  def pro_connect_required?
    return false if !ProConnectService.enabled?

    pro_connect_required_at? || Flipper.enabled?(:pro_connect_required_for_all_administrateurs, user)
  end

  # The only MFA available is the ProConnect one: the MFA wave is a subset
  # of the ProConnect wave.
  def mfa_required?
    pro_connect_required? && Flipper.enabled?(:administrateur_mfa_required, user)
  end

  def owns?(procedure)
    procedure.administrateurs.include?(self)
  end

  def instructeur
    user.instructeur
  end

  def can_be_deleted?
    procedures.with_discarded.not_brouillon.all? { |p| p.administrateurs.count > 1 || p.dossiers.empty? }
  end

  def merge(old_admin)
    return if old_admin.nil?

    procedures_with_new_admin, procedures_without_new_admin = old_admin
      .procedures
      .with_discarded
      .partition { |p| p.administrateurs.exists?(id) }

    procedures_with_new_admin.each do |p|
      p.administrateurs.delete(old_admin)
    end

    procedures_without_new_admin.each do |p|
      p.administrateurs << self
      p.administrateurs.delete(old_admin)
    end

    old_services = old_admin.services
    new_service_by_nom = services.index_by(&:nom)

    old_services.each do |old_service|
      corresponding_service = new_service_by_nom[old_service.nom]
      if corresponding_service.present?
        old_service.procedures.with_discarded.update_all(service_id: corresponding_service.id)
        old_service.destroy
      else
        old_service.update_column(:administrateur_id, id)
      end
    end

    instructeurs_with_new_admin, instructeurs_without_new_admin = old_admin.instructeurs
      .partition { |i| i.administrateurs.exists?(id) }

    instructeurs_with_new_admin.each do |i|
      i.administrateurs.delete(old_admin)
    end

    instructeurs_without_new_admin.each do |i|
      i.administrateurs << self
      i.administrateurs.delete(old_admin)
    end

    # v1/v2 tokens are deliberately left behind (and destroyed with the old
    # admin): we want their owners to migrate to v3 tokens.
    old_admin.api_tokens.where(version: 3..).find_each do |token|
      self.api_tokens << token
    end
  end

  def zones
    procedures.includes(:zones).flat_map(&:zones).uniq
  end

  # required to display feature flags field in manager
  def features
  end

  def unread_commentaires?
    commentaire_groupe_gestionnaires.last && (commentaire_seen_at.nil? || commentaire_seen_at < commentaire_groupe_gestionnaires.last.created_at)
  end

  def mark_commentaire_as_seen
    update(commentaire_seen_at: Time.zone.now)
  end
end
