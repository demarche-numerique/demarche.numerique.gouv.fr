# frozen_string_literal: true

class GroupeInstructeur < ApplicationRecord
  include Logic
  DEFAUT_LABEL = 'défaut'
  belongs_to :procedure, -> { with_discarded }, inverse_of: :groupe_instructeurs, optional: false
  has_many :assign_tos, dependent: :destroy
  has_many :instructeurs, through: :assign_tos
  has_many :dossiers
  has_many :deleted_dossiers
  has_many :batch_operations, through: :dossiers, source: :batch_operations
  has_many :assignments, class_name: 'DossierAssignment', dependent: :nullify, inverse_of: :groupe_instructeur
  has_many :previous_assignments, class_name: 'DossierAssignment', dependent: :nullify, inverse_of: :previous_groupe_instructeur
  has_many :export_templates, dependent: :destroy
  has_and_belongs_to_many :exports, dependent: :destroy

  has_one :defaut_procedure, -> { with_discarded }, class_name: 'Procedure', foreign_key: :defaut_groupe_instructeur_id, dependent: :nullify, inverse_of: :defaut_groupe_instructeur
  has_one :contact_information, dependent: :destroy

  has_one_attached :signature

  SIGNATURE_MAX_SIZE = 1.megabyte
  validates :signature, content_type: ['image/png', 'image/jpeg'], size: { less_than: SIGNATURE_MAX_SIZE }, empty_file: true

  validates :label, presence: true, allow_nil: false
  validates :label, uniqueness: { scope: :procedure }
  validates :closed, acceptance: { accept: [false] }, if: -> { (self == procedure.defaut_groupe_instructeur) }

  normalizes :label, with: -> (value) { value.strip }

  scope :without_group, -> (group) { where.not(id: group) }
  scope :for_api_v2, -> { includes(procedure: [:administrateurs]) }
  scope :active, -> { where(closed: false) }
  scope :closed, -> { where(closed: true) }
  scope :for_dossiers, -> (dossiers) { joins(:dossiers).where(dossiers: dossiers).distinct(:id) }

  def add(instructeur)
    return if instructeur.nil?

    assign_to = instructeur.assign_to.create_or_find_by(groupe_instructeur: self)
    DossierNotification.refresh_notifications_new_instructeur_for_dossiers(self, instructeur) if assign_to.previously_new_record?
  end

  def remove(instructeur)
    return if instructeur.nil?
    return if !in?(instructeur.groupe_instructeurs)

    transaction do
      instructeur.groupe_instructeurs.destroy(self)
      InstructeursProcedure.find_by(procedure: self.procedure, instructeur:)&.delete if !instructeur.procedures.include?(self.procedure)

      instructeur.follows
        .joins(:dossier)
        .where(dossiers: { groupe_instructeur: self })
        .update_all(unfollowed_at: Time.zone.now)

      DossierNotification.destroy_notifications_instructeur_of_groupe_instructeur(self, instructeur)
    end
  end

  def add_instructeurs(ids: [], emails: [])
    instructeurs_to_add, valid_emails, invalid_emails = Instructeur.find_all_by_identifier_with_emails(ids:, emails:)
    not_found_emails = valid_emails - instructeurs_to_add.map(&:email)

    # Send invitations to users without account
    if not_found_emails.present?
      instructeurs_to_add += not_found_emails.map do |email|
        user = User.create_or_promote_to_instructeur(email, SecureRandom.hex, administrateurs: procedure.administrateurs)
        user.instructeur
      end
    end

    # We dont't want to assign a user to a groupe_instructeur if they are already assigned to it
    instructeurs_to_add -= instructeurs
    instructeurs_to_add.compact!

    new_instructeurs = instructeurs_to_add.filter { |instructeur| instructeur.assign_to.create_or_find_by(groupe_instructeur: self).previously_new_record? }
    DossierNotification.refresh_notifications_new_instructeurs_for_groupe(self, new_instructeurs)

    [instructeurs_to_add, invalid_emails]
  end

  def can_delete?
    id != procedure.defaut_groupe_instructeur_id &&
      dossiers.empty? &&
      (procedure.groupe_instructeurs.active.many? || (procedure.groupe_instructeurs.active.one? && closed))
  end

  def can_close?
    id != procedure.defaut_groupe_instructeur_id
  end

  def update_rule_statuses
    update_rule_validity_status
    procedure.update_all_groupes_rule_unicity_status
  end

  def update_rule_validity_status
    update!(valid_routing_rule: valid_rule?)
  end

  def defaut?
    id == procedure.defaut_groupe_instructeur_id
  end

  def routing_to_configure?
    return false if defaut? && routing_rule.nil?
    invalid_rule? || non_unique_rule?
  end

  def invalid_rule?
    !valid_rule?
  end

  # A rule is valid when it is well formed on the champs of the active
  # revision and can actually match a dossier (no contradictory rows).
  def valid_rule?
    return false if routing_rule.nil? || routing_rule.is_a?(EmptyOperator)

    Logic.errors(routing_rule, procedure.active_revision.public_root_type_de_champs).blank?
  end

  def non_unique_rule?
    return false if invalid_rule?
    routing_rule.in?(other_groupe_instructeurs.map(&:routing_rule))
  end

  def groups_with_same_rule
    return if routing_rule.nil?
    other_groupe_instructeurs
      .filter { _1.routing_rule.present? }
      .filter { _1.routing_rule == routing_rule }
      .map(&:label)
      .join(', ')
  end

  def other_groupe_instructeurs
    procedure.groupe_instructeurs - [self]
  end

  def humanized_routing_rule
    routing_rule&.to_s(procedure.active_revision.type_de_champs)
  end

  serialize :routing_rule, coder: LogicSerializer
end
