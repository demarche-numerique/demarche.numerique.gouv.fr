# frozen_string_literal: true

class Instructeur < ApplicationRecord
  alias_attribute :pro_connect_id_token, :agent_connect_id_token

  include UserFindByConcern
  has_and_belongs_to_many :administrateurs

  has_many :assign_to, dependent: :destroy
  has_many :groupe_instructeurs, -> { order(:label) }, through: :assign_to
  has_many :unordered_groupe_instructeurs, through: :assign_to, source: :groupe_instructeur
  has_many :procedures, -> { distinct }, through: :unordered_groupe_instructeurs
  has_many :deleted_dossiers, through: :procedures
  has_many :batch_operations, dependent: :nullify
  has_many :export_templates, through: :groupe_instructeurs
  has_many :commentaires, inverse_of: :instructeur, dependent: :nullify
  has_many :dossiers, -> { state_not_brouillon }, through: :unordered_groupe_instructeurs
  has_many :follows, -> { active }, inverse_of: :instructeur, dependent: :destroy
  has_many :previous_follows, -> { inactive }, class_name: 'Follow', inverse_of: :instructeur, dependent: :destroy
  has_many :followed_dossiers, through: :follows, source: :dossier
  has_many :previously_followed_dossiers, -> { distinct }, through: :previous_follows, source: :dossier
  has_many :trusted_device_tokens, dependent: :destroy
  has_many :bulk_messages, dependent: :destroy
  has_many :exports, as: :user_profile
  has_many :archives, as: :user_profile
  has_many :instructeurs_procedures, dependent: :destroy
  has_many :dossier_notifications, dependent: :destroy

  has_one :rdv_connection, dependent: :destroy

  belongs_to :user

  validates :user_id, uniqueness: true

  scope :with_instant_email_new_message, -> (procedure) {
    joins(:instructeurs_procedures)
      .where(instructeurs_procedures: {
        procedure:,
        instant_email_new_message: true,
      })
  }

  scope :with_instant_email_new_expert_avis, -> (procedure) {
    joins(:instructeurs_procedures)
      .where(instructeurs_procedures: {
        procedure:,
        instant_email_new_expert_avis: true,
      })
  }

  scope :with_instant_email_new_dossier, -> (procedure) {
    joins(:instructeurs_procedures)
      .where(instructeurs_procedures: {
        procedure:,
        instant_email_new_dossier: true,
      })
  }

  scope :with_daily_email_summary, -> {
    joins(:instructeurs_procedures)
      .where(instructeurs_procedures: {
        daily_email_summary: true,
      })
      .distinct
  }

  scope :with_instant_email_dossier_deletion, -> (procedure) {
    where.not(
      id: InstructeursProcedure
            .select(:instructeur_id)
            .where(procedure:)
            .where(instant_email_dossier_deletion: false)
    )
  }

  default_scope { eager_load(:user) }

  def email
    user.email
  end

  def follow(dossier)
    begin
      followed_dossiers << dossier

      DossierNotification.refresh_notifications_instructeur_for_followed_dossier(self, dossier)

      # If the user tries to follow a dossier she already follows,
      # we just fail silently: it means the goal is already reached.
    rescue ActiveRecord::RecordNotUnique
      # Database uniqueness constraint
    rescue ActiveRecord::RecordInvalid => e
      # ActiveRecord validation
      raise unless e.record.errors.details.dig(:instructeur_id, 0, :error) == :taken
    end
  end

  def unfollow(dossier)
    f = follows.find_by(dossier: dossier)
    if f.present?
      f.update(unfollowed_at: Time.zone.now)
      DossierNotification.destroy_notifications_instructeur_of_unfollowed_dossier(self, dossier)
    end
  end

  def follow?(dossier)
    followed_dossiers.include?(dossier)
  end

  def assign_to_procedure(procedure)
    if !procedure.defaut_groupe_instructeur.in?(groupe_instructeurs)
      groupe_instructeurs << procedure.defaut_groupe_instructeur
    end
  end

  def procedure_presentation_for_procedure_id(procedure_id)
    assign_to = assign_to_for_procedure_id(procedure_id)
    assign_to.procedure_presentation || assign_to.create_procedure_presentation!
  end

  def procedure_presentation_and_errors_for_procedure_id(procedure_id)
    assign_to = assign_to_for_procedure_id(procedure_id)
    assign_to.procedure_presentation_or_default_and_errors
  end

  def mark_tab_as_seen(dossier, tab)
    attributes = {}
    attributes["#{tab}_seen_at"] = Time.zone.now
    Follow.where(instructeur: self, dossier: dossier).update_all(attributes)
  end

  def daily_email_summary_data
    groupe_instructeurs
      .joins(procedure: :instructeurs_procedures)
      .where(instructeurs_procedures: {
        instructeur: self,
        daily_email_summary: true,
      })
      .merge(Procedure.publiee)
      .group_by(&:procedure_id)
      .reduce([]) do |acc, (_, groupe_instructeurs)|
      procedure = groupe_instructeurs.first.procedure
      dossiers_count = self.dossiers.where(groupe_instructeur: groupe_instructeurs).visible_by_administration.group(:state).count

      h = {
        nb_en_construction: dossiers_count['en_construction'] || 0,
        nb_en_instruction: dossiers_count['en_instruction'] || 0,
        nb_accepted: dossiers_count['accepte'] || 0,
        nb_refused: dossiers_count['refuse'] || 0,
        nb_closed_without_continuation: dossiers_count['sans_suite'] || 0,
      }

      if h.values.any?(&:positive?)
        h[:procedure_id] = procedure.id
        h[:procedure_libelle] = procedure.libelle
        h[:nb_processed] = h[:nb_accepted] + h[:nb_refused] + h[:nb_closed_without_continuation]

        notifications_data = DossierNotification.notifications_count_for_email_data(groupe_instructeurs.map(&:id), self)
        h[:nb_dossiers_with_notifications] = notifications_data.first
        h[:nb_notifications] = notifications_data.second

        acc << h
      end

      acc
    end
  end

  def weekly_email_summary_data
    procedures = self.procedures
      .joins(:instructeurs_procedures)
      .where(instructeurs_procedures: {
        instructeur: self,
        weekly_email_summary: true,
      })
      .publiees
      .includes(dossiers: :groupe_instructeur)

    gi_ids = groupe_instructeurs.ids

    procedure_overviews = procedures.map do |procedure|
      dossiers = procedure
        .dossiers
        .filter { |d| gi_ids.include?(d.groupe_instructeur_id) && d.visible_by_administration? }

      ProcedureOverview.new(procedure, dossiers)
    end

    active_procedure_overviews = procedure_overviews.filter(&:had_some_activities?)

    active_procedure_overviews.empty? ? nil : active_procedure_overviews
  end

  def create_trusted_device_token
    trusted_device_token = trusted_device_tokens.create
    trusted_device_token.token
  end

  def young_login_token?
    trusted_device_token = trusted_device_tokens.order(created_at: :desc).first
    trusted_device_token&.token_young?
  end

  def should_receive_email_activation?
    # if was recently created or received an activation email more than 7 days ago
    previously_new_record? || user.reset_password_sent_at.nil? || user.reset_password_sent_at < Devise.reset_password_within.ago
  end

  def can_be_deleted?
    user.administrateur.nil? && procedures.all? { |p| p.defaut_groupe_instructeur.instructeurs.count > 1 }
  end

  # required to display feature flags field in manager
  def features
  end

  def dossiers_count_summary(groupe_instructeur_ids)
    query = <<~EOF
      SELECT
        COUNT(DISTINCT dossiers.id) FILTER (where dossiers.hidden_by_administration_at IS NULL AND dossiers.hidden_by_expired_at IS NULL AND not archived AND dossiers.state in ('en_construction', 'en_instruction') AND follows.id IS NULL) AS a_suivre,
        COUNT(DISTINCT dossiers.id) FILTER (where dossiers.hidden_by_administration_at IS NULL AND dossiers.hidden_by_expired_at IS NULL AND not archived AND dossiers.state in ('en_construction', 'en_instruction') AND follows.instructeur_id = :instructeur_id) AS suivis,
        COUNT(DISTINCT dossiers.id) FILTER (where dossiers.hidden_by_administration_at IS NULL AND dossiers.hidden_by_expired_at IS NULL AND not archived AND dossiers.state in ('accepte', 'refuse', 'sans_suite')) AS traites,
        COUNT(DISTINCT dossiers.id) FILTER (where dossiers.hidden_by_administration_at IS NULL AND dossiers.hidden_by_expired_at IS NULL AND not archived) AS tous,
        COUNT(DISTINCT dossiers.id) FILTER (where dossiers.hidden_by_administration_at IS NULL AND dossiers.hidden_by_expired_at IS NULL AND archived) AS archives,
        COUNT(DISTINCT dossiers.id) FILTER (where dossiers.hidden_by_administration_at IS NOT NULL AND not archived OR dossiers.hidden_by_expired_at IS NOT NULL) AS supprimes,
        COUNT(DISTINCT dossiers.id) FILTER (where dossiers.hidden_by_administration_at IS NULL AND dossiers.hidden_by_expired_at IS NULL AND procedures.procedure_expires_when_termine_enabled AND (dossiers.expired_at - INTERVAL '#{Expired::REMAINING_WEEKS_BEFORE_EXPIRATION} weeks' < :now)) AS expirant
      FROM dossiers
        INNER JOIN procedure_revisions
          ON procedure_revisions.id = dossiers.revision_id
        INNER JOIN procedures
          ON procedures.id = procedure_revisions.procedure_id
        LEFT OUTER JOIN follows
          ON  follows.dossier_id = dossiers.id
          AND follows.unfollowed_at IS NULL
      WHERE dossiers.state != 'brouillon'
        AND dossiers.groupe_instructeur_id in (:groupe_instructeur_ids)
        AND (dossiers.hidden_by_user_at IS NULL OR dossiers.state != 'en_construction')
    EOF

    sanitized_query = ActiveRecord::Base.sanitize_sql([
      query,
      instructeur_id: id,
      groupe_instructeur_ids: groupe_instructeur_ids,
      now: Time.current,
    ])

    Dossier.connection.select_all(sanitized_query).first
  end

  def merge(old_instructeur)
    return if old_instructeur.nil?

    old_instructeur
      .assign_to
      .where.not(groupe_instructeur_id: assign_to.pluck(:groupe_instructeur_id))
      .update_all(instructeur_id: id)

    old_instructeur
      .follows
      .where.not(dossier_id: follows.pluck(:dossier_id))
      .update_all(instructeur_id: id)

    admin_with_new_instructeur, admin_without_new_instructeur = old_instructeur
      .administrateurs
      .partition { |admin| admin.instructeurs.exists?(id) }

    admin_without_new_instructeur.each do |admin|
      admin.instructeurs << self
      admin.instructeurs.delete(old_instructeur)
    end

    admin_with_new_instructeur.each do |admin|
      admin.instructeurs.delete(old_instructeur)
    end
    old_instructeur.commentaires.update_all(instructeur_id: id)
    old_instructeur.bulk_messages.update_all(instructeur_id: id)

    Avis
      .where(claimant_id: old_instructeur.id, claimant_type: Instructeur.name)
      .update_all(claimant_id: id)
  end

  def last_pro_connect_information
    user.last_pro_connect_information
  end

  def export_templates_for(procedure)
    procedure.export_templates
      .where(groupe_instructeur: groupe_instructeurs)
      .includes(:groupe_instructeur)
      .order(:name)
      .to_a
  end

  TemplateExportGroup = Data.define(:name, :templates)
  def export_template_options_for(procedure)
    shareable_export_templates = procedure.export_templates
      .shareable
      .where.not(groupe_instructeur: groupe_instructeurs)
      .includes(:groupe_instructeur)
      .order(:name).to_a
    my_export_templates = export_templates_for(procedure)

    if shareable_export_templates.present?
      [TemplateExportGroup['Mes modèles d’export', my_export_templates], TemplateExportGroup['Modèles d’export partagés', shareable_export_templates]]
    else
      my_export_templates
    end
  end

  def groupe_instructeur_options_for(procedure)
    groupe_instructeurs.where(procedure:).pluck(:label, :id)
  end

  def feature_enabled?(feature)
    Flipper.enabled?(feature, self)
  end

  private

  def assign_to_for_procedure_id(procedure_id)
    assign_to
      .joins(:groupe_instructeur)
      .includes(:instructeur, :procedure)
      .find_by(groupe_instructeurs: { procedure_id: procedure_id })
  end
end
