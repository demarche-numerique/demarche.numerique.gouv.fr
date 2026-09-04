# frozen_string_literal: true

class Dossier < ApplicationRecord
  # The search columns are only ever read and written as raw SQL: loading them as
  # attributes would carry a full-text blob on every dossier instance.
  self.ignored_columns += [:search_terms, :private_search_terms, :search_terms_tsvector, :all_search_terms_tsvector]

  include DossierCloneConcern
  include DossierCorrectableConcern
  include DossierFranceConnectPrefillConcern
  include DossierMessagerieConcern
  include DossierPendingResponseConcern
  include DossierFilteringConcern
  include DossierPrefillableConcern
  include DossierRebaseConcern
  include DossierSearchableConcern
  include DossierSectionsConcern
  include DossierStateConcern
  include DossierStreamConcern
  include DossierChampsConcern
  include DossierExportConcern
  include DossierValidateConcern

  enum :state, {
    brouillon:       'brouillon',
    en_construction: 'en_construction',
    en_instruction:  'en_instruction',
    accepte:         'accepte',
    refuse:          'refuse',
    sans_suite:      'sans_suite',
  }

  INSTRUCTION_ACTIONS = [
    :accepter,
    :refuser,
    :classer_sans_suite,
  ].freeze

  def self.instruction_action?(action)
    return false if action.blank?
    INSTRUCTION_ACTIONS.include?(action.to_sym)
  end

  EN_CONSTRUCTION_OU_INSTRUCTION = [states.fetch(:en_construction), states.fetch(:en_instruction)]
  TERMINE = [states.fetch(:accepte), states.fetch(:refuse), states.fetch(:sans_suite)]
  INSTRUCTION_COMMENCEE = TERMINE + [states.fetch(:en_instruction)]
  SOUMIS = EN_CONSTRUCTION_OU_INSTRUCTION + TERMINE

  REMAINING_DAYS_BEFORE_CLOSING = 2
  INTERVAL_BEFORE_CLOSING = "#{REMAINING_DAYS_BEFORE_CLOSING} days"
  REMAINING_WEEKS_BEFORE_DELETION = 2
  CONSERVATION_EXTENSION_DURATION = 1.month

  has_secure_token :prefill_token

  has_one :etablissement, dependent: :destroy
  has_one :individual, validate: false, dependent: :destroy
  has_one :attestation, dependent: :destroy

  # FIXME: some dossiers have more than one attestation
  has_many :attestations, dependent: :destroy

  has_one_attached :justificatif_motivation
  has_one_attached :attestation_depot_pdf

  # autosave persists champ changes when saving the dossier; champ validation
  # is driven by DossierValidateConcern over projected champs, so `validate: false`
  # keeps autosave from cascading validation into every loaded champ.
  has_many :champ_data, dependent: :destroy, class_name: 'ChampData', autosave: true, validate: false
  has_many :commentaires, inverse_of: :dossier, dependent: :destroy
  has_many :commentaires_chronological, -> { chronological }, class_name: 'Commentaire', inverse_of: :dossier
  has_many :preloaded_commentaires, -> { includes(:dossier_correction, :dossier_pending_response, :instructeur, :expert, piece_jointe_attachments: :blob).order(created_at: :desc) }, class_name: 'Commentaire', inverse_of: :dossier

  has_many :invites, dependent: :destroy
  has_many :follows, -> { active }, inverse_of: :dossier, dependent: :destroy
  has_many :previous_follows, -> { inactive }, class_name: 'Follow', inverse_of: :dossier, dependent: :destroy
  has_many :followers_instructeurs, through: :follows, source: :instructeur
  has_many :previous_followers_instructeurs, -> { distinct }, through: :previous_follows, source: :instructeur
  has_many :avis, -> { order(:created_at) }, inverse_of: :dossier, dependent: :destroy
  has_many :experts, through: :avis
  has_many :traitements, -> { order(:processed_at) }, inverse_of: :dossier, dependent: :destroy do
    def passer_en_construction(instructeur: nil, processed_at: Time.zone.now)
      build(state: Dossier.states.fetch(:en_construction),
        instructeur_email: instructeur&.email,
        processed_at:,
        revision_id: proxy_association.owner.revision_id,
        browser: Current.browser)
    end

    def usager_submit_en_construction(processed_at: Time.zone.now, checkpoint:)
      build(state: Dossier.states.fetch(:en_construction),
        checkpoint:,
        processed_at:,
        revision_id: proxy_association.owner.revision_id,
        browser: Current.browser)
    end

    def instructeur_submit_en_construction(instructeur:, checkpoint:, motivation: nil, processed_at: Time.zone.now)
      build(state: Dossier.states.fetch(:en_construction),
        instructeur_email: instructeur.email,
        motivation:,
        checkpoint:,
        processed_at:,
        revision_id: proxy_association.owner.revision_id,
        browser: Current.browser)
    end

    def passer_en_instruction(instructeur: nil, processed_at: Time.zone.now)
      build(state: Dossier.states.fetch(:en_instruction),
        instructeur_email: instructeur&.email,
        processed_at:,
        revision_id: proxy_association.owner.revision_id,
        browser: Current.browser)
    end

    def accepter_automatiquement(processed_at: Time.zone.now)
      build(state: Dossier.states.fetch(:accepte),
        processed_at:,
        revision_id: proxy_association.owner.revision_id)
    end

    def accepter(motivation: nil, instructeur: nil, processed_at: Time.zone.now)
      build(state: Dossier.states.fetch(:accepte),
        instructeur_email: instructeur&.email,
        motivation:,
        processed_at:,
        revision_id: proxy_association.owner.revision_id,
        browser: Current.browser)
    end

    def refuser(motivation: nil, instructeur: nil, processed_at: Time.zone.now)
      build(state: Dossier.states.fetch(:refuse),
        instructeur_email: instructeur&.email,
        motivation:,
        processed_at:,
        revision_id: proxy_association.owner.revision_id,
        browser: Current.browser)
    end

    def refuser_automatiquement(processed_at: Time.zone.now, motivation:)
      build(state: Dossier.states.fetch(:refuse),
        motivation:,
        processed_at:,
        revision_id: proxy_association.owner.revision_id)
    end

    def classer_sans_suite(motivation: nil, instructeur: nil, processed_at: Time.zone.now)
      build(state: Dossier.states.fetch(:sans_suite),
        instructeur_email: instructeur&.email,
        motivation:,
        processed_at:,
        revision_id: proxy_association.owner.revision_id,
        browser: Current.browser)
    end
  end
  has_one :traitement, -> { order(processed_at: :desc) }, inverse_of: false

  has_many :dossier_operation_logs, -> { order(:created_at) }, inverse_of: :dossier
  has_many :dossier_assignments, -> { order(:assigned_at) }, inverse_of: :dossier, dependent: :destroy
  has_one :dossier_assignment, -> { order(assigned_at: :desc) }, inverse_of: false

  belongs_to :groupe_instructeur, optional: true
  belongs_to :revision, class_name: 'ProcedureRevision', optional: false
  belongs_to :submitted_revision, class_name: 'ProcedureRevision', optional: true, inverse_of: false
  belongs_to :user, optional: true
  belongs_to :batch_operation, optional: true
  has_many :dossier_batch_operations, dependent: :destroy
  has_many :batch_operations, through: :dossier_batch_operations

  has_one :procedure, through: :revision
  has_one :attestation_acceptation_template, through: :procedure
  has_one :attestation_refus_template, through: :procedure

  delegate :public_root_type_de_champs, :private_root_type_de_champs, :has_france_connect_type_de_champ?, to: :revision

  belongs_to :transfer, class_name: 'DossierTransfer', foreign_key: 'dossier_transfer_id', optional: true, inverse_of: :dossiers
  has_many :transfer_logs, class_name: 'DossierTransferLog', dependent: :destroy
  has_many :dossier_labels, dependent: :destroy
  has_many :labels, -> { order(:position, :id) }, through: :dossier_labels
  has_many :dossier_notifications, dependent: :destroy

  has_many :rdvs, dependent: :destroy

  after_destroy_commit :log_destroy

  accepts_nested_attributes_for :individual, update_only: true

  include AASM

  aasm whiny_persistence: true, column: :state, enum: true do
    state :brouillon, initial: true
    state :en_construction
    state :en_instruction
    state :accepte
    state :refuse
    state :sans_suite

    event :passer_en_construction, after: :after_passer_en_construction, after_commit: :after_commit_passer_en_construction do
      transitions from: :brouillon, to: :en_construction, guard: :can_passer_en_construction?
    end

    event :passer_en_instruction, after: :after_passer_en_instruction, after_commit: :after_commit_passer_en_instruction do
      transitions from: :en_construction, to: :en_instruction, guard: :can_passer_en_instruction?
    end

    event :passer_automatiquement_en_instruction, after: :after_passer_automatiquement_en_instruction, after_commit: :after_commit_passer_automatiquement_en_instruction do
      transitions from: :en_construction, to: :en_instruction, guard: :can_passer_automatiquement_en_instruction?
    end

    event :repasser_en_construction, after: :after_repasser_en_construction, after_commit: :after_commit_repasser_en_construction do
      transitions from: :en_instruction, to: :en_construction, guard: :can_repasser_en_construction?
    end

    event :repasser_en_construction_with_pending_correction, after: :after_repasser_en_construction, after_commit: :after_commit_repasser_en_construction do
      transitions from: :en_instruction, to: :en_construction
    end

    event :accepter, after: :after_accepter, after_commit: :after_commit_accepter do
      transitions from: :en_instruction, to: :accepte, guard: :can_terminer?
    end

    event :accepter_automatiquement, after: :after_accepter_automatiquement, after_commit: :after_commit_accepter_automatiquement do
      transitions from: :en_construction, to: :accepte, guard: :can_accepter_automatiquement?
      transitions from: :en_instruction, to: :accepte, guard: :can_accepter_automatiquement?
    end

    event :refuser, after: :after_refuser, after_commit: :after_commit_refuser do
      transitions from: :en_instruction, to: :refuse, guard: :can_terminer?
    end

    event :refuser_automatiquement, after: :after_refuser_automatiquement, after_commit: :after_commit_refuser_automatiquement do
      transitions from: :en_instruction, to: :refuse, guard: :can_refuser_automatiquement?
    end

    event :classer_sans_suite, after: :after_classer_sans_suite, after_commit: :after_commit_classer_sans_suite do
      transitions from: :en_instruction, to: :sans_suite, guard: :can_terminer?
    end

    event :repasser_en_instruction, after: :after_repasser_en_instruction, after_commit: :after_commit_repasser_en_instruction do
      transitions from: :refuse, to: :en_instruction, guard: :can_repasser_en_instruction?
      transitions from: :sans_suite, to: :en_instruction, guard: :can_repasser_en_instruction?
      transitions from: :accepte, to: :en_instruction, guard: :can_repasser_en_instruction?
    end
  end

  scope :state_brouillon,                      -> { where(state: states.fetch(:brouillon)) }
  scope :state_not_brouillon,                  -> { where.not(state: states.fetch(:brouillon)) }
  scope :state_en_construction,                -> { where(state: states.fetch(:en_construction)) }
  scope :state_not_en_construction,            -> { where.not(state: states.fetch(:en_construction)) }
  scope :state_en_instruction,                 -> { where(state: states.fetch(:en_instruction)) }
  scope :state_en_construction_ou_instruction, -> { where(state: EN_CONSTRUCTION_OU_INSTRUCTION) }
  scope :state_instruction_commencee,          -> { where(state: INSTRUCTION_COMMENCEE) }
  scope :state_termine,                        -> { where(state: TERMINE) }
  scope :state_not_termine,                    -> { where.not(state: TERMINE) }
  scope :state_accepte,                        -> { where(state: states.fetch(:accepte)) }
  scope :state_refuse,                         -> { where(state: states.fetch(:refuse)) }
  scope :state_sans_suite,                     -> { where(state: states.fetch(:sans_suite)) }

  scope :archived,                  -> { where(archived: true) }
  scope :not_archived,              -> { where(archived: false) }
  scope :prefilled,                 -> { where(prefilled: true) }
  scope :hidden_by_user,            -> { where.not(hidden_by_user_at: nil) }
  scope :hidden_by_administration,  -> { where.not(hidden_by_administration_at: nil) }
  scope :hidden_by_expired,         -> { where.not(hidden_by_expired_at: nil) }
  scope :hidden_by_not_modified_for_a_long_time, -> { hidden_by_expired.where(hidden_by_reason: :not_modified_for_a_long_time) }
  scope :hidden_by_procedure_removed, -> { hidden_by_administration.where(hidden_by_reason: :procedure_removed) }
  scope :submitted_to_administration, -> {
    state_not_brouillon
      .where("state != :state OR hidden_by_reason IS NULL OR hidden_by_reason != :reason",
        state: "en_construction",
        reason: "user_request")
  }
  scope :visible_by_user,           -> { where(for_procedure_preview: false, hidden_by_user_at: nil, hidden_by_expired_at: nil) }
  scope :visible_by_administration, -> {
    state_not_brouillon
      .where(hidden_by_administration_at: nil)
      .where(hidden_by_expired_at: nil)
      .merge(visible_by_user.or(state_not_en_construction))
  }
  scope :visible_by_user_or_administration, -> { visible_by_user.or(visible_by_administration) }
  scope :hidden_for_administration, -> {
    state_not_brouillon.hidden_by_administration.or(state_en_construction.hidden_by_user)
  }
  scope :for_procedure_preview, -> { where(for_procedure_preview: true) }
  scope :for_groupe_instructeur, -> (groupe_instructeurs) { where(groupe_instructeur: groupe_instructeurs) }
  scope :order_by_updated_at,            -> (order = :desc) { order(updated_at: order, id: order) }
  scope :order_by_depose_at,             -> (order = :desc) { order(depose_at: order, id: order) }
  scope :order_by_created_at,            -> (order = :asc) { order(depose_at: order, id: order) }
  scope :updated_since,                  -> (since) { where(dossiers: { updated_at: since.. }) }
  scope :created_since,                  -> (since) { where(dossiers: { depose_at: since.. }) }
  scope :hidden_by_user_since,           -> (since) { where('dossiers.hidden_by_user_at IS NOT NULL AND dossiers.hidden_by_user_at >= ?', since) }
  scope :hidden_by_administration_since, -> (since) { where('dossiers.hidden_by_administration_at IS NOT NULL AND dossiers.hidden_by_administration_at >= ?', since) }
  scope :hidden_since,                   -> (since) { hidden_by_user_since(since).or(hidden_by_administration_since(since)) }

  scope :with_type_de_champ, -> (stable_id) { joins(:champ_data).where(champs: { stream: MAIN_STREAM, stable_id: }) }
  scope :without_type_de_champ, -> (stable_id) { where.not(id: with_type_de_champ(stable_id).select(:id)) }

  scope :all_state,                   -> (include_archived: false) { include_archived ? state_not_brouillon : not_archived.state_not_brouillon }
  scope :en_construction,             -> { not_archived.state_en_construction }
  scope :en_instruction,              -> { not_archived.state_en_instruction }
  scope :termine,                     -> { not_archived.state_termine }

  scope :archivable, -> { visible_by_administration.state_termine }

  scope :archivable_by_month, -> (all_groupe_instructeurs) {
    archivable
      .where(groupe_instructeur: all_groupe_instructeurs)
      .group_by_period(:month, :processed_at, reverse: true)
  }

  scope :archivable_in_month, -> (date) do
    date = date.to_datetime
    archivable
      .where(processed_at: date.all_month)
  end
  scope :ordered_for_export, -> {
    order(depose_at: 'asc')
  }
  scope :en_cours,                    -> { not_archived.state_en_construction_ou_instruction }
  scope :without_followers,           -> { where.missing(:follows) }
  scope :with_followers,              -> { left_outer_joins(:follows).where.not(follows: { id: nil }) }
  scope :brouillons_recently_updated, -> { updated_since(2.days.ago).state_brouillon.order_by_updated_at }
  scope :for_api, -> {
    includes(commentaires: { piece_jointe_attachments: :blob },
      justificatif_motivation_attachment: :blob,
      attestation: [],
      avis: { piece_justificative_file_attachment: :blob },
      traitement: [],
      etablissement: [],
      individual: [],
      user: [])
  }

  scope :with_notifiable_procedure, -> (opts = { notify_on_closed: false }) do
    states = opts[:notify_on_closed] ? [:publiee, :close, :depubliee] : [:publiee, :depubliee]
    joins(:procedure)
      .where(procedures: { aasm_state: states })
      .where.not(user_id: nil)
  end

  scope :brouillon_close_to_expiration, -> do
    state_brouillon
      .visible_by_user
      .where(expired_at: ..(Time.zone.now + Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks))
  end
  scope :termine_close_to_expiration, -> do
    state_termine
      .visible_by_user_or_administration
      .where(expired_at: ..(Time.zone.now + Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks))
  end

  scope :close_to_expiration, -> do
    brouillon_close_to_expiration
      .or(termine_close_to_expiration)
  end

  scope :never_touched_brouillon_expired, -> { visible_by_user.brouillon.where.missing(:etablissement, :individual).where(last_champ_updated_at: nil, identity_updated_at: nil, parent_dossier: nil, last_commentaire_updated_at: nil).where(created_at: ..2.weeks.ago) }
  scope :brouillon_expired_after_notice_grace, -> do
    state_brouillon
      .visible_by_user
      .where(brouillon_close_to_expiration_notice_sent_at: ...(Time.zone.now - Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks))
  end

  scope :brouillon_expired_without_notice, -> do
    state_brouillon
      .where(expired_at: ..Time.zone.now)
      .where(hidden_by_user_at: nil)
      .joins(:procedure)
      .where("dossiers.for_procedure_preview = TRUE OR procedures.aasm_state IN (?)", %w[close brouillon])
  end

  scope :termine_expired_after_notice_grace, -> do
    state_termine
      .visible_by_user_or_administration
      .where(termine_close_to_expiration_notice_sent_at: ...(Time.zone.now - Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks))
  end

  scope :without_brouillon_expiration_notice_sent, -> { where(brouillon_close_to_expiration_notice_sent_at: nil) }
  scope :without_termine_expiration_notice_sent, -> { where(termine_close_to_expiration_notice_sent_at: nil) }
  scope :without_dossier_expirant_notification, -> do
    where.not(
      DossierNotification
        .where("dossier_notifications.dossier_id = dossiers.id")
        .where(notification_type: :dossier_expirant)
        .arel.exists
    )
  end

  scope :deleted_by_user_expired, -> { where(dossiers: { hidden_by_user_at: ...REMAINING_WEEKS_BEFORE_DELETION.weeks.ago }) }
  scope :deleted_by_administration_expired, -> { where(dossiers: { hidden_by_administration_at: ...REMAINING_WEEKS_BEFORE_DELETION.weeks.ago }) }
  scope :deleted_by_automatic_expired, -> { where(dossiers: { hidden_by_expired_at: ...REMAINING_WEEKS_BEFORE_DELETION.weeks.ago }) }
  scope :en_brouillon_expired_to_delete, -> { state_brouillon.deleted_by_user_expired.or(state_brouillon.deleted_by_automatic_expired) }
  scope :en_construction_expired_to_delete, -> { state_en_construction.deleted_by_user_expired.or(state_en_construction.deleted_by_automatic_expired) }
  scope :termine_expired_to_delete, -> { state_termine.deleted_by_user_expired.deleted_by_administration_expired.or(state_termine.deleted_by_automatic_expired) }

  scope :brouillon_near_procedure_closing_date, -> do
    # select users who have submitted dossier for the given 'procedures.id'
    users_who_submitted =
      state_not_brouillon
        .visible_by_user
        .joins(:revision)
        .where("procedure_revisions.procedure_id = procedures.id")
        .select(:user_id)
    # select dossier in brouillon where procedure closes in two days and for which the user has not submitted a Dossier
    state_brouillon
      .visible_by_user
      .with_notifiable_procedure
      .where("procedures.auto_archive_on - INTERVAL '#{INTERVAL_BEFORE_CLOSING}' = :today", { today: Time.zone.today })
      .where.not(user: users_who_submitted)
  end

  scope :with_revision, -> { includes(revision: :revision_type_de_champs) }
  scope :for_api_v2, -> {
    with_revision
      .includes(:attestation_acceptation_template, :attestation_refus_template, :etablissement, :individual, :traitement, procedure: [:administrateurs], user: [:france_connect_informations])
  }

  scope :with_notifications, -> (instructeur) {
    joins(:dossier_notifications)
      .where(dossier_notifications: { instructeur_id: instructeur.id })
      .merge(DossierNotification.to_display)
      .distinct
  }

  scope :order_by_notifications_importance, -> do
    includes(:dossier_notifications)
      .sort_by do |dossier|
        dossier.dossier_notifications.map do |notif|
          DossierNotification.notification_types.keys.index(notif.notification_type)
        end.min
      end
  end

  scope :by_statut, -> (statut, instructeur: nil, include_archived: false) do
    case statut
    when 'a-suivre'
      visible_by_administration
        .without_followers
        .en_cours
    when 'suivis'
      instructeur
        .followed_dossiers
        .merge(visible_by_administration)
        .en_cours
    when 'traites'
      visible_by_administration.termine
    when 'tous'
      visible_by_administration.all_state(include_archived:)
    when 'supprimes'
      hidden_by_administration.state_termine.or(hidden_by_expired)
    when 'archives'
      visible_by_administration.archived
    when 'expirant'
      visible_by_administration.termine_close_to_expiration
    end
  end

  scope :not_having_batch_operation, -> { where(batch_operation_id: nil) }

  def with_revision
    ::ActiveRecord::Associations::Preloader.new(
      records: [self],
      associations: { revision: :revision_type_de_champs }
    ).call
    self
  end

  def with_champs(blob: false)
    DossierPreloader.load_one(self, pj_template: blob)
  end

  delegate :siret, :siren, to: :etablissement, allow_nil: true
  delegate :france_connected_with_one_identity?, to: :user, allow_nil: true

  def identity_from_fc?
    user&.can_prefill_from_fc?(with_gender: !procedure.no_gender?)
  end

  after_save :send_web_hook
  after_save :update_expired_at, if: :brouillon?

  validates :user, presence: true, if: -> { deleted_user_email_never_send.nil? }, unless: -> { prefilled }
  validates :individual, presence: true, if: -> { revision.procedure.for_individual? }
  # A brouillon may transiently be for_tiers without mandataire identity: the
  # persona choice is persisted as soon as it is made on the identity step,
  # before the names are submitted. Deposit still enforces presence (the state
  # is already en_construction when the transition saves).
  validates :mandataire_first_name, presence: true, if: -> { for_tiers? && !brouillon? }
  validates :mandataire_last_name, presence: true, if: -> { for_tiers? && !brouillon? }
  validates :for_tiers, inclusion: { in: [true, false] }, if: -> { revision&.procedure&.for_individual? }

  # csv/ods construisent tout le classeur en mémoire d'un coup (spreadsheet_architect) :
  # on matérialise donc l'ensemble des dossiers triés et préchargés. On passe par
  # `in_batches` seulement pour précharger les champs par tranches adaptatives
  # (plutôt qu'en une requête champs géante), et on rassemble les batches.
  def self.downloadable_sorted_batch
    [].tap do |dossiers|
      DossierPreloader.new(ordered_for_export)
        .in_batches(includes: DossierPreloader::SHEET_EXPORT_INCLUDES) { |batch| dossiers.concat(batch) }
    end
  end

  def user_deleted?
    persisted? && user_id.nil?
  end

  def user_email_for(use)
    if user_deleted?
      if use == :display
        deleted_user_email_never_send
      else
        raise "Can not send email to discarded user"
      end
    else
      user.email
    end
  end

  def user_email_for_display
    user_email_for(:display)
  end

  def last_booked_rdv
    rdvs.booked.by_starts_at.last
  end

  def expiration_started?
    [
      brouillon_close_to_expiration_notice_sent_at,
      termine_close_to_expiration_notice_sent_at,
    ].any?(&:present?)
  end

  def motivation
    if termine?
      traitement&.motivation || read_attribute(:motivation)
    end
  end

  def build_default_values
    build_default_individual
    build_default_champs
  end

  def en_construction_ou_instruction?
    EN_CONSTRUCTION_OU_INSTRUCTION.include?(state)
  end

  def termine?
    TERMINE.include?(state)
  end

  def instruction_commencee?
    INSTRUCTION_COMMENCEE.include?(state)
  end

  def read_only?
    en_instruction? || accepte? || refuse? || sans_suite? || procedure.discarded? || procedure.close? && brouillon?
  end

  def can_transition_to_en_construction?
    brouillon? && procedure.dossier_can_transition_to_en_construction? && !for_procedure_preview?
  end

  def can_terminer?
    return false if any_etablissement_as_degraded_mode?
    return false unless champs_private_valid?

    true
  end

  def can_accepter_automatiquement?
    return false unless can_terminer?
    return true if declarative_triggered_at.nil? && procedure.declarative_accepte? && en_construction?
    return true if procedure.sva? && can_terminer_automatiquement_by_sva_svr?

    false
  end

  def can_refuser_automatiquement?
    return false unless can_terminer?
    return true if procedure.svr? && can_terminer_automatiquement_by_sva_svr?

    false
  end

  def blocked_with_pending_correction?
    procedure.publiee? && procedure.feature_enabled?(:blocking_pending_correction) && pending_correction?
  end

  def can_passer_en_construction?
    !ineligibilite_triggered?(filled_champs_public)
  end

  # Same rule as can_passer_en_construction?, minus the champs the usager never
  # wrote: their implicit answer would make the rule true on an untouched
  # brouillon. Every other champ keeps its weight.
  def ineligibilite_triggered_by_answered_champs?
    champs = brouillon? ? filled_champs_public.reject(&:implicit_value?) : filled_champs_public

    ineligibilite_triggered?(champs)
  end

  def can_passer_en_instruction?
    return false if blocked_with_pending_correction?

    true
  end

  def can_passer_automatiquement_en_instruction?
    return true if procedure.auto_archive_on? && !procedure.auto_archive_on.future? && !pending_correction?
    return false if !can_passer_en_instruction?
    return true if declarative_triggered_at.nil? && procedure.declarative_en_instruction?
    return true if procedure.sva_svr_enabled? && sva_svr_decision_triggered_at.nil? && !pending_correction?

    false
  end

  def can_repasser_en_construction?
    !procedure.sva_svr_enabled?
  end

  def can_repasser_en_instruction?
    termine? && !user_deleted?
  end

  def can_be_updated_by_user?
    brouillon? || en_construction?
  end

  def can_be_deleted_by_user?
    brouillon? || en_construction? || termine?
  end

  def can_be_deleted_by_administration?(reason)
    termine? || reason == :procedure_removed
  end

  def can_be_deleted_by_automatic?(reason)
    reason == :expired && !en_instruction?
  end

  def can_terminer_automatiquement_by_sva_svr?
    sva_svr_decision_triggered_at.nil? && !pending_correction? && (sva_svr_decision_on.today? || sva_svr_decision_on.past?)
  end

  def any_etablissement_as_degraded_mode?
    return true if etablissement&.as_degraded_mode?
    return true if filled_champs_public.any? { _1.etablissement&.as_degraded_mode? }

    false
  end

  def messagerie_available?
    visible_by_administration? && !hidden_by_user? && !user_deleted? && !archived
  end

  def expirable?
    brouillon? || termine?
  end

  def close_to_expiration?
    return false if en_instruction? || en_construction?
    return false if expired_at.nil?
    expired_at < Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.from_now && Time.zone.now < expired_at
  end

  def nb_days_before_expiration
    (expired_at.to_date - Date.current).to_i
  end

  def has_expired?
    return false if en_instruction? || en_construction?

    notice_sent_at =
      if brouillon?
        brouillon_close_to_expiration_notice_sent_at
      elsif termine?
        termine_close_to_expiration_notice_sent_at
      end

    return false if notice_sent_at.nil?

    notice_sent_at < Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.ago
  end

  def expiration_date_reference
    if brouillon?
      [last_champ_updated_at, identity_updated_at].compact.max || updated_at
    elsif en_construction?
      en_construction_at
    elsif termine?
      processed_at
    else
      fail "expiration_date_reference should not be called in state #{self.state}"
    end
  end

  def expiration_date_with_extension
    expiration_date_reference + duree_totale_conservation_in_months.months
  end

  def duree_totale_conservation_in_months
    duree_conservation_dossier = brouillon? ? [procedure.duree_conservation_dossiers_dans_ds, Expired::MONTHS_BEFORE_BROUILLON_EXPIRATION].min : procedure.duree_conservation_dossiers_dans_ds

    duree_conservation_dossier + (conservation_extension / 1.month.to_i)
  end

  def after_notification_expiration_date
    if brouillon? && brouillon_close_to_expiration_notice_sent_at.present?
      brouillon_close_to_expiration_notice_sent_at + Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks
    elsif termine? && termine_close_to_expiration_notice_sent_at.present?
      termine_close_to_expiration_notice_sent_at + Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks
    end
  end

  def expiration_date
    return nil if en_instruction? || en_construction?

    after_notification_expiration_date.presence || expiration_date_with_extension
  end

  def update_expired_at = update_column(:expired_at, expiration_date)

  def expiration_can_be_extended?
    brouillon?
  end

  def extend_conservation(conservation_extension)
    update(conservation_extension: self.conservation_extension + conservation_extension,
      brouillon_close_to_expiration_notice_sent_at: nil,
      termine_close_to_expiration_notice_sent_at: nil)
    update_expired_at
    DossierNotification.destroy_notifications_by_dossier_and_type(self, :dossier_expirant)
  end

  def extend_conservation_and_restore(conservation_extension, author)
    extend_conservation(conservation_extension)
    update(hidden_by_expired_at: nil, hidden_by_reason: nil)
    restore(author)
  end

  def show_procedure_state_warning?
    procedure.discarded? || (brouillon? && !procedure.dossier_can_transition_to_en_construction?)
  end

  def assign_to_groupe_instructeur(groupe_instructeur, mode, author = nil)
    return if groupe_instructeur.present? && groupe_instructeur.procedure != procedure
    return if self.groupe_instructeur == groupe_instructeur && mode == self.dossier_assignment&.mode

    previous_groupe_instructeur = self.groupe_instructeur

    track_assigned_dossier_without_groupe_instructeur if groupe_instructeur.nil?

    update!(groupe_instructeur:, groupe_instructeur_updated_at: Time.zone.now)
    update!(forced_groupe_instructeur: true) if mode == DossierAssignment.modes.fetch(:manual)

    create_assignment(mode, previous_groupe_instructeur, groupe_instructeur, author&.email)

    if !brouillon?
      unfollow_stale_instructeurs
      update_notifications(previous_groupe_instructeur, groupe_instructeur) if previous_groupe_instructeur.present?

      if author.present?
        log_dossier_operation(author, :changer_groupe_instructeur, self)
      end
    end
  end

  def archiver!(instructeur)
    update!(archived: true, archived_at: Time.zone.now, archived_by: instructeur.email)
  end

  def desarchiver!
    update!(archived: false, archived_at: nil, archived_by: nil)
  end

  def text_summary
    I18n.t(
      "dossiers.text_summary.#{brouillon? ? :brouillon : :depose}",
      date: depose_at && I18n.l(depose_at.to_date, format: :short),
      procedure: procedure.libelle,
      organisme: procedure.organisation_name
    )
  end

  def avis_for_expert(expert)
    Avis
      .where(dossier_id: id, confidentiel: false)
      .or(Avis.where(id: expert.avis, dossier_id: id)) # avis's asked to expert
      .or(Avis.where(claimant: expert, dossier_id: id)) # avis's claimed by expert
      .order(created_at: :asc)
  end

  def owner_name
    if etablissement.present?
      etablissement.entreprise_raison_sociale
    elsif individual.present?
      "#{individual.nom} #{individual.prenom}"
    end
  end

  def orphan?
    prefilled? && user.nil?
  end

  def owned_by?(a_user)
    return false if a_user.nil?
    return false if orphan?

    user == a_user
  end

  def log_operations?
    !procedure.brouillon? && !brouillon?
  end

  def hidden_by_expired?
    hidden_by_expired_at.present?
  end

  def hidden_by_user?
    hidden_by_user_at.present?
  end

  def hidden_by_administration?
    hidden_by_administration_at.present?
  end

  def hidden_for_administration?
    hidden_by_administration? || (hidden_by_user? && en_construction?) || brouillon?
  end

  def visible_by_administration?
    !hidden_for_administration?
  end

  def hidden_for_administration_and_user?
    hidden_for_administration? && hidden_by_user?
  end

  def expose_legacy_carto_api?
    procedure.expose_legacy_carto_api?
  end

  def geo_position
    if etablissement.present?
      point = Geocoder.search(etablissement.geo_adresse).first
    end

    lon = Champs::CarteChamp::DEFAULT_LON.to_s
    lat = Champs::CarteChamp::DEFAULT_LAT.to_s
    zoom = "13"

    if point.present?
      lat, lon = point.coordinates.map(&:to_s)
    end

    { lon: lon, lat: lat, zoom: zoom }
  end

  def unspecified_attestation_champs(kind)
    attestation_template = attestation_template_for(kind)
    if attestation_template&.activated?
      attestation_template.unspecified_champs_for_dossier(self)
    else
      []
    end
  end

  def attestation_template_for(kind)
    public_send("attestation_#{kind}_template")
  end

  def enqueue_attestation_generation
    return if attestation.present?

    template = if accepte?
      attestation_template_for(AttestationTemplate.kinds.fetch(:acceptation))
    elsif refuse?
      attestation_template_for(AttestationTemplate.kinds.fetch(:refus))
    end

    return if template.blank?
    return if !template.activated?

    AttestationPdfGenerationJob.perform_later(self)
  end

  def generate_or_reuse_attestation_depot
    if attestation_depot_pdf.attached? && attestation_depot_pdf.blob.created_at.today? && attestation_depot_pdf.blob.created_at > updated_at
      return attestation_depot_pdf.blob.download
    end

    html = ApplicationController.render(
      template: 'users/dossiers/attestation_depot',
      layout: 'attestation',
      assigns: { dossier: self }
    )

    options = { procedure_id: procedure.id, dossier_id: id }

    pdf = WeasyprintService.generate_pdf(html, options)

    attestation_depot_pdf.attach(
      io: StringIO.new(pdf),
      filename: "attestation-depot-dossier-#{id}.pdf",
      content_type: 'application/pdf'
    )

    pdf
  end

  def is_user?(author)
    author.is_a?(User)
  end

  def is_administration?(author)
    author.is_a?(Instructeur) || author.is_a?(Administrateur) || author.is_a?(SuperAdmin)
  end

  def is_automatic?(author)
    author == :automatic
  end

  def hide_and_keep_track!(author, reason)
    transaction do
      if is_administration?(author) && can_be_deleted_by_administration?(reason)
        update(hidden_by_administration_at: Time.zone.now, hidden_by_reason: reason)
        log_dossier_operation(author, :supprimer, self)
        DossierNotification.create_notifications_for_non_customisable_type(self, :dossier_suppression) if hidden_by_user?
      elsif is_user?(author) && can_be_deleted_by_user?
        update(hidden_by_user_at: Time.zone.now, dossier_transfer_id: nil, hidden_by_reason: reason)
        log_dossier_operation(author, :supprimer, self)
        DossierNotification.create_notifications_for_non_customisable_type(self, :dossier_suppression) if hidden_by_administration?
      elsif is_automatic?(author) && can_be_deleted_by_automatic?(reason)
        update(hidden_by_expired_at: Time.zone.now, hidden_by_reason: reason)
        log_automatic_dossier_operation(:supprimer, self)
      else
        raise "Unauthorized dossier hide attempt Dossier##{id} by #{author} for reason #{reason}"
      end
    end

    if en_construction? && !hidden_by_administration?
      followers_to_notify_emails = followers_instructeurs.with_instant_email_dossier_deletion(procedure).pluck(:email)

      followers_to_notify_emails.each do |email|
        DossierMailer.notify_en_construction_deletion_to_administration(self, email).deliver_later
      end
    end
  end

  def restore(author)
    transaction do
      if is_administration?(author)
        update(hidden_by_administration_at: nil)
        DossierNotification.destroy_notifications_by_dossier_and_type(self, :dossier_suppression)
      elsif is_user?(author)
        update(hidden_by_user_at: nil)
      end

      if is_user?(author) && hidden_by_reason&.to_sym == :not_modified_for_a_long_time
        update(hidden_by_expired_at: nil)
      elsif !hidden_by_user? && !hidden_by_administration?
        update(hidden_by_reason: nil)
      elsif hidden_by_user?
        update(hidden_by_reason: :user_request)
      elsif hidden_by_administration?
        update(hidden_by_reason: :instructeur_request)
      end

      log_dossier_operation(author, :restaurer, self)
    end
  end

  def email_template_for(state)
    procedure.email_template_for(state)
  end

  def process_declarative!
    if procedure.declarative_accepte? && may_accepter_automatiquement?
      accepter_automatiquement!
    elsif procedure.declarative_en_instruction? && may_passer_automatiquement_en_instruction?
      passer_automatiquement_en_instruction!
    end
  end

  def process_sva_svr!
    return unless procedure.sva_svr_enabled?
    return if sva_svr_decision_triggered_at.present?

    # set or recompute sva date, except for dossiers submitted before sva was enabled
    if depose_at.today? || sva_svr_decision_on.present?
      self.sva_svr_decision_on = SVASVRDecisionDateCalculatorService.new(self, procedure).decision_date
    end

    return if sva_svr_decision_on.nil?

    if en_construction? && may_passer_automatiquement_en_instruction?
      passer_automatiquement_en_instruction!
    elsif en_instruction? && procedure.sva? && may_accepter_automatiquement?
      accepter_automatiquement!
    elsif en_instruction? && procedure.svr? && may_refuser_automatiquement?
      refuser_automatiquement!
    elsif will_save_change_to_sva_svr_decision_on?
      save! # we always want the most up to date decision when there is a pending correction
    end
  end

  def previously_termine?
    traitements.any?(&:termine?)
  end

  def demander_un_avis!(avis)
    log_dossier_operation(avis.claimant, :demander_un_avis, avis)
  end

  def linked_dossiers_for(instructeur_or_expert)
    dossier_ids = filled_champs.filter(&:dossier_link?).filter_map(&:value)
    instructeur_or_expert.dossiers.where(id: dossier_ids)
  end

  def hash_for_deletion_mail
    { id: self.id, procedure_libelle: self.procedure.libelle, procedure_path: self.procedure.path }
  end

  def geo_data?
    GeoArea.exists?(champ_id: filled_champs)
  end

  def to_feature_collection
    {
      type: 'FeatureCollection',
      id: id,
      bbox: bounding_box,
      features: geo_areas.map(&:to_feature),
    }
  end

  def log_api_entreprise_job_exception(exception)
    exceptions = self.api_entreprise_job_exceptions ||= []
    exceptions << exception.inspect
    update_column(:api_entreprise_job_exceptions, exceptions)
  end

  def user_locale
    user&.locale || I18n.default_locale
  end

  def purge_discarded
    purge_freeing_champs_cascade do
      DeletedDossier.create_from_dossier(self, hidden_by_reason)
      dossier_operation_logs.purge_discarded
    end
  end

  # Suppression silencieuse d'un brouillon expiré jamais notifié (preview ou
  # procédure non-notifiable). Pas de DeletedDossier ni d'email, comme la
  # suppression de brouillon existante.
  def purge_without_notice
    purge_freeing_champs_cascade
  end

  def skip_user_notification_email?
    return true if for_procedure_preview?
    return true if user_deleted?

    false
  end

  def sva_svr_decision_in_days
    (sva_svr_decision_on - Date.current).to_i
  end

  def create_assignment(mode, previous_groupe_instructeur, groupe_instructeur, instructeur_email = nil)
    DossierAssignment.create!(
      dossier_id: self.id,
      mode: mode,
      previous_groupe_instructeur_id: previous_groupe_instructeur&.id,
      groupe_instructeur_id: groupe_instructeur.id,
      previous_groupe_instructeur_label: previous_groupe_instructeur&.label,
      groupe_instructeur_label: groupe_instructeur.label,
      assigned_at: Time.zone.now,
      assigned_by: instructeur_email
    )
  end

  def service_or_contact_information
    if procedure.routing_enabled?
      groupe_instructeur&.contact_information || procedure.service
    else
      procedure.service
    end
  end

  def mandataire_full_name
    "#{mandataire_first_name} #{mandataire_last_name}"
  end

  def user_from_france_connect?
    return false if user_deleted?
    user.france_connected_with_one_identity?
  end

  def has_annotations?
    revision.private_root_type_de_champs.present?
  end

  def hide_info_with_accuse_lecture?
    procedure.accuse_lecture? && termine? && accuse_lecture_agreement_at.blank?
  end

  def termine_and_accuse_lecture?
    procedure.accuse_lecture? && termine?
  end

  def update_champs_timestamps(changed_champs, stream)
    return if changed_champs.empty?
    updated_at = Time.zone.now
    attributes = { updated_at: }
    if stream == USER_BUFFER_STREAM
      attributes[:last_champ_updated_at] = updated_at
    elsif stream == INSTRUCTEUR_BUFFER_STREAM
      attributes[:last_champ_instructeur_updated_at] = updated_at
    end
    update_columns(attributes)
  end

  def revision_changed_since_submitted?
    submitted_revision_id.present? && submitted_revision_id != revision_id
  end

  def enqueue_fetch_external_data_jobs(prefilled_champs)
    prefilled_champs.each do |champ|
      if champ.has_async_external_data? && champ.may_fetch_later?
        champ.fetch_later!
      end
    end
  end

  def prefill_and_enqueue_fetch_external_data_jobs(champs, type_de_champs)
    prefilled_champs = Array.wrap(champs).flat_map do |champ|
      champ.propagate_prefill(type_de_champs)
    end
    enqueue_fetch_external_data_jobs(prefilled_champs)
  end

  private

  # Détruit le dossier en libérant la cascade des champs (geo_areas, etablissement,
  # AS attachments) par lots de 50 avant le destroy, évitant le pic mémoire dû au
  # chargement complet de la cascade dependent: :destroy. Le bloc optionnel exécute
  # la traçabilité (DeletedDossier, operation logs) dans la même transaction.
  # Important: destroy_all (et non delete_all) preserve les callbacks Rails.
  def purge_freeing_champs_cascade
    transaction do
      yield if block_given?
      champ_data.in_batches(of: 50).each(&:destroy_all)
      destroy
    rescue => e
      Sentry.capture_exception(e, extra: { dossier: id })
      # Rollback explicite : sans cela, le rescue avale l'erreur et la transaction
      # commit un état partiel (champs deja batch-destroy, dossier intact).
      raise ActiveRecord::Rollback
    end
  end

  def ineligibilite_triggered?(champs)
    return false if !revision.ineligibilite_enabled || !revision.ineligibilite_rules

    revision.ineligibilite_rules.compute(champs)
  end

  def build_default_champs
    build_default_champs_for(revision.public_root_type_de_champs) if !champ_data.any?(&:public?)
    build_default_champs_for(revision.private_root_type_de_champs) if !champ_data.any?(&:private?)
  end

  def build_default_champs_for(type_de_champs)
    self.champ_data << type_de_champs.filter(&:fillable?).filter_map do |type_de_champ|
      if type_de_champ.repetition?
        if type_de_champ.private? || type_de_champ.mandatory?
          type_de_champ.build_champ(dossier: self, row_id: ULID.generate)
        end
      else
        type_de_champ.build_champ(dossier: self, row_id: nil)
      end
    end
  end

  def build_default_individual
    if procedure.for_individual? && individual.blank?
      self.individual = if france_connected_with_one_identity?
        Individual.from_france_connect(user.france_connect_informations.first)
      else
        Individual.new
      end
    end
  end

  def create_missing_traitemets
    if en_construction_at.present? && traitements.en_construction.empty?
      self.traitements.passer_en_construction(processed_at: en_construction_at)
      self.depose_at ||= en_construction_at
    end
    if en_instruction_at.present? && traitements.en_instruction.empty?
      self.traitements.passer_en_instruction(processed_at: en_instruction_at)
    end
  end

  def deleted_dossier
    return @deleted_dossier if defined?(@deleted_dossier)

    @deleted_dossier = DeletedDossier.find_by(dossier_id: id)
  end

  def defaut_groupe_instructeur?
    groupe_instructeur == procedure.defaut_groupe_instructeur
  end

  def geo_areas
    ActiveRecord::Associations::Preloader.new(records: filled_champs, associations: :geo_areas).call
    filled_champs.flat_map(&:geo_areas)
  end

  def bounding_box
    GeojsonService.bbox(type: 'FeatureCollection', features: geo_areas.map(&:to_feature))
  end

  def log_dossier_operation(author, operation, subject = nil)
    if log_operations?
      DossierOperationLog.create_and_serialize(
        dossier: self,
        operation: DossierOperationLog.operations.fetch(operation),
        author: author,
        subject: subject
      )
    end
  end

  def log_automatic_dossier_operation(operation, subject = nil)
    if log_operations?
      DossierOperationLog.create_and_serialize(
        dossier: self,
        operation: DossierOperationLog.operations.fetch(operation),
        automatic_operation: true,
        subject: subject
      )
    end
  end

  def send_web_hook
    if saved_change_to_state? && !brouillon? && procedure.web_hook_url.present?
      WebHookJob.perform_later(
        procedure.id,
        self.id,
        self.state,
        self.updated_at
      )
    end
  end

  def unfollow_stale_instructeurs
    followers_instructeurs.each do |instructeur|
      if instructeur.groupe_instructeurs.exclude?(groupe_instructeur)
        instructeur.unfollow(self)
        if visible_by_administration?
          DossierMailer.notify_groupe_instructeur_changed(instructeur, self).deliver_later
        end
      end
    end
    followers_instructeurs.reset
  end

  def self.notify_draft_not_submitted
    brouillon_near_procedure_closing_date
      .find_each do |dossier|
        DossierMailer.notify_brouillon_not_submitted(dossier).deliver_later
      end
  end

  def send_dossier_decision_to_experts(dossier)
    avis_experts_procedures_ids = Avis
      .joins(:experts_procedure)
      .where(dossier: dossier, experts_procedures: { allow_decision_access: true })
      .with_answer
      .distinct
      .pluck('avis.id, experts_procedures.id')

    # rubocop:disable Lint/UnusedBlockArgument
    avis = avis_experts_procedures_ids
      .uniq { |(avis_id, experts_procedures_id)| experts_procedures_id }
      .map { |(avis_id, _)| avis_id }
      .then { |avis_ids| Avis.find(avis_ids) }
    # rubocop:enable Lint/UnusedBlockArgument

    avis.each { |a| ExpertMailer.send_dossier_decision(a).deliver_later }
  end

  def log_destroy
    app_traces = caller.reject { _1.match?(%r{/ruby/.+/gems/}) }.map { _1.sub(Rails.root.to_s, "") }

    payload = {
      message: "Dossier destroyed #{id}",
      dossier_id: id,
      procedure_id: procedure.id,
      request_id: Current.request_id,
      user_id: Current.user&.id,
      controller: app_traces.find { _1.match?(%r{/controllers/|/jobs/}) },
      caller: app_traces.first,
      hidden_by_reason:,
    }

    logger = Lograge.logger || Rails.logger

    logger.info payload.to_json
  end

  def track_assigned_dossier_without_groupe_instructeur
    Sentry.capture_message(
      "Assigned dossier without groupe_instructeur",
      extra: {
        dossier_id: self.id,
      }
    )
  end

  def update_notifications(previous_groupe_instructeur, new_groupe_instructeur)
    previous_instructeur_ids = previous_groupe_instructeur.instructeurs.ids
    new_instructeur_ids = new_groupe_instructeur.instructeurs.ids
    instructeur_removed_ids = previous_instructeur_ids - new_instructeur_ids
    instructeur_added_ids = new_instructeur_ids - previous_instructeur_ids

    DossierNotification.destroy_notifications_instructeurs_of_old_dossier(instructeur_removed_ids, self) if instructeur_removed_ids.any?
    DossierNotification.refresh_notifications_new_instructeurs_for_dossier(instructeur_added_ids, self) if instructeur_added_ids.any?
  end
end
