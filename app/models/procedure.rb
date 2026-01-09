# frozen_string_literal: true

class Procedure < ApplicationRecord
  include APIEntrepriseTokenConcern
  include ProcedureStatsConcern
  include InitiationProcedureConcern
  include ProcedureGroupeInstructeurAPIHackConcern
  include ProcedureSVASVRConcern
  include ProcedureChorusConcern
  include ProcedurePublishConcern
  include ProcedurePathConcern
  include ProcedureCloneConcern
  include PiecesJointesListConcern
  include ColumnsConcern
  include RoutingRuleStatusesConcern

  include Discard::Model
  self.discard_column = :hidden_at

  self.ignored_columns += ["api_entreprise_token_expires_at", "pro_connect_restricted"]

  default_scope -> { kept }

  OLD_MAX_DUREE_CONSERVATION = 36

  MIN_WEIGHT = 350000

  DOSSIERS_COUNT_EXPIRING = 1.hour

  encrypts :api_particulier_token

  has_many :revisions, -> { order(:id) }, class_name: 'ProcedureRevision', inverse_of: :procedure
  belongs_to :draft_revision, class_name: 'ProcedureRevision', optional: false
  belongs_to :published_revision, class_name: 'ProcedureRevision', optional: true
  has_many :deleted_dossiers, dependent: :destroy
  has_many :llm_rule_suggestions, through: :revisions

  def draft_types_de_champ_public = draft_revision&.types_de_champ_public || []
  def draft_types_de_champ_private = draft_revision&.types_de_champ_private || []
  def published_types_de_champ_public = published_revision&.types_de_champ_public || []
  def published_types_de_champ_private = published_revision&.types_de_champ_private || []

  has_one :published_dossier_submitted_message, dependent: :destroy, through: :published_revision, source: :dossier_submitted_message
  has_one :draft_dossier_submitted_message, dependent: :destroy, through: :draft_revision, source: :dossier_submitted_message
  has_many :dossier_submitted_messages, through: :revisions, source: :dossier_submitted_message

  has_many :experts_procedures, dependent: :destroy
  has_many :experts, through: :experts_procedures
  has_many :replaced_procedures, -> { with_discarded }, inverse_of: :replaced_by_procedure, class_name: "Procedure",
  foreign_key: "replaced_by_procedure_id", dependent: :nullify

  has_one :module_api_carto, dependent: :destroy
  has_many :attestation_templates, dependent: :destroy
  has_one :attestation_template_v1, -> { AttestationTemplate.v1 }, dependent: :destroy, class_name: "AttestationTemplate", inverse_of: :procedure

  has_many :attestation_acceptation_templates_v2, -> { AttestationTemplate.v2.where(kind: "acceptation") }, dependent: :destroy, class_name: "AttestationTemplate", inverse_of: :procedure
  has_many :attestation_refus_templates_v2, -> { AttestationTemplate.v2.where(kind: "refus") }, dependent: :destroy, class_name: "AttestationTemplate", inverse_of: :procedure

  has_one :attestation_acceptation_template,
          -> { published.where(kind: "acceptation") },
          class_name: "AttestationTemplate",
          dependent: :destroy,
          inverse_of: :procedure

  has_one :attestation_refus_template,
          -> { published.where(kind: "refus") },
          class_name: "AttestationTemplate",
          dependent: :destroy,
          inverse_of: :procedure

  belongs_to :parent_procedure, class_name: 'Procedure', optional: true
  belongs_to :canonical_procedure, class_name: 'Procedure', optional: true
  belongs_to :replaced_by_procedure, -> { with_discarded }, inverse_of: :replaced_procedures, class_name: "Procedure", optional: true
  belongs_to :service, optional: true
  belongs_to :zone, optional: true
  has_and_belongs_to_many :zones
  has_and_belongs_to_many :procedure_tags

  has_many :bulk_messages, dependent: :destroy
  has_many :labels, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :procedure

  has_many :instructeurs_procedures, dependent: :destroy

  def active_dossier_submitted_message
    published_dossier_submitted_message || draft_dossier_submitted_message
  end

  def active_revision
    brouillon? ? draft_revision : published_revision
  end

  def all_revisions_types_de_champ(parent: nil, with_header_section: false)
    types_de_champ_scope = with_header_section ? TypeDeChamp.with_header_section : TypeDeChamp.fillable
    if brouillon?
      if parent.nil?
        types_de_champ_scope
          .joins(:revision_types_de_champ)
          .where(revision_types_de_champ: { revision_id: draft_revision_id, parent_id: nil })
          .order(:private, :position)
      else
        draft_revision.children_of(parent)
      end
    else
      cache_key = ['all_revisions_types_de_champ', published_revision, parent, with_header_section].compact
      Rails.cache.fetch(cache_key, expires_in: 1.month) { published_revisions_types_de_champ(parent:, with_header_section:) }
    end
  end

  def types_de_champ_for_procedure_export
    all_revisions_types_de_champ.not_repetition
  end

  def types_de_champ_for_tags
    TypeDeChamp
      .fillable
      .joins(:revisions)
      .where(procedure_revisions: brouillon? ? { id: draft_revision_id } : { procedure_id: id })
      .where(revision_types_de_champ: { parent_id: nil })
      .order(:created_at)
      .distinct(:id)
  end

  def types_de_champ_public_for_tags
    types_de_champ_for_tags.public_only
  end

  def types_de_champ_private_for_tags
    types_de_champ_for_tags.private_only
  end

  def revisions_with_pending_dossiers
    @revisions_with_pending_dossiers ||= begin
      ids = dossiers
        .where.not(revision_id: [draft_revision_id, published_revision_id].compact)
        .state_en_construction_ou_instruction
        .distinct(:revision_id)
        .pluck(:revision_id)
      ProcedureRevision.includes(:revision_types_de_champ).where(id: ids)
    end
  end

  has_many :administrateurs_procedures, dependent: :delete_all
  has_many :administrateurs, through: :administrateurs_procedures, before_remove: :check_administrateur_minimal_presence
  has_many :groupe_instructeurs, -> { order(:label) }, inverse_of: :procedure, dependent: :destroy
  has_many :instructeurs, through: :groupe_instructeurs
  has_many :export_templates, through: :groupe_instructeurs

  has_many :active_groupe_instructeurs, -> { active }, class_name: 'GroupeInstructeur', inverse_of: false
  has_many :closed_groupe_instructeurs, -> { closed }, class_name: 'GroupeInstructeur', inverse_of: false

  # This relationship is used in following dossiers through. We can not use revisions relationship
  # as order scope introduces invalid sql in some combinations.
  has_many :unordered_revisions, class_name: 'ProcedureRevision', inverse_of: :procedure, dependent: :destroy
  has_many :dossiers, through: :unordered_revisions, dependent: :restrict_with_exception

  has_many :rdvs, through: :dossiers

  has_one :initiated_mail, class_name: "Mails::InitiatedMail", dependent: :destroy
  has_one :received_mail, class_name: "Mails::ReceivedMail", dependent: :destroy
  has_one :closed_mail, class_name: "Mails::ClosedMail", dependent: :destroy
  has_one :refused_mail, class_name: "Mails::RefusedMail", dependent: :destroy
  has_one :without_continuation_mail, class_name: "Mails::WithoutContinuationMail", dependent: :destroy
  has_one :re_instructed_mail, class_name: "Mails::ReInstructedMail", dependent: :destroy

  belongs_to :defaut_groupe_instructeur, class_name: 'GroupeInstructeur', inverse_of: false, optional: true

  has_one_attached :logo
  has_one_attached :notice
  has_one_attached :deliberation

  scope :brouillons,             -> { where(aasm_state: :brouillon) }
  scope :not_brouillon,          -> { where.not(aasm_state: :brouillon) }
  scope :publiees,               -> { where(aasm_state: :publiee) }
  scope :publiees_ou_brouillons, -> { where(aasm_state: [:publiee, :brouillon]) }
  scope :closes,                 -> { where(aasm_state: [:close, :depubliee]) }
  scope :opendata,               -> { where(opendata: true) }
  scope :publiees_ou_closes,     -> { where(aasm_state: [:publiee, :close, :depubliee]) }

  scope :with_external_urls,     -> { where.not(lien_notice: [nil, '']).or(where.not(lien_dpo: [nil, ''])) }

  scope :publiques,              -> do
    publiees_ou_closes
      .opendata
      .where(estimated_dossiers_count: 4..)
      .where.not('lien_site_web LIKE ?', '%mail%')
      .where.not('lien_site_web LIKE ?', '%intra%')
  end

  scope :by_libelle,             -> { order(libelle: :asc) }
  scope :created_during,         -> (range) { where(created_at: range) }
  scope :cloned_from_library,    -> { where(cloned_from_library: true) }
  scope :declarative,            -> { where.not(declarative_with_state: nil) }

  scope :discarded_expired, -> do
    with_discarded
      .discarded
      .where(hidden_at: ...1.month.ago)
  end

  scope :for_api, -> { with_active_revision.includes(:administrateurs, :module_api_carto) }
  scope :for_api_v2, -> { with_active_revision.includes(administrateurs: :user) }
  scope :with_active_revision, -> { includes(draft_revision: :revision_types_de_champ, published_revision: :revision_types_de_champ) }

  scope :order_by_position_for, -> (instructeur) {
    joins(:instructeurs_procedures)
      .select('procedures.*, instructeurs_procedures.position AS position')
      .where(instructeurs_procedures: { instructeur_id: instructeur.id })
      .order(position: :desc)
  }

  enum :declarative_with_state, {
    en_instruction:  'en_instruction',
    accepte:         'accepte',
  }

  enum :closing_reason, {
    internal_procedure: 'internal_procedure',
    other: 'other',
  }, prefix: true

  enum :pro_connect_restriction, {
    none: 'none',
    instructeurs: 'instructeurs',
    all: 'all',
  }, prefix: true

  validates :libelle, presence: true, allow_blank: false, allow_nil: false
  validates :description, presence: true, allow_blank: false, allow_nil: false
  validates :administrateurs, presence: true

  validates :lien_site_web, presence: true, if: :publiee?
  validates :lien_notice, url: { no_local: true, allow_blank: true }
  validates :lien_dpo, url: { no_local: true, allow_blank: true, accept_email: true }

  validates :draft_types_de_champ_public,
    'types_de_champ/condition': true,
    'types_de_champ/header_section_consistency': true,
    'types_de_champ/no_empty_block': true,
    'types_de_champ/no_empty_drop_down': true,
    'types_de_champ/formatted': true,
    'types_de_champ/referentiel_ready': true,
    'types_de_champ/libelle': true,
    on: [:types_de_champ_public_editor, :publication]

  validates :draft_types_de_champ_private,
    'types_de_champ/condition': true,
    'types_de_champ/header_section_consistency': true,
    'types_de_champ/no_empty_block': true,
    'types_de_champ/no_empty_drop_down': true,
    'types_de_champ/formatted': true,
    'types_de_champ/referentiel_ready': true,
    'types_de_champ/libelle': true,
    on: [:types_de_champ_private_editor, :publication]

  validate :check_juridique, on: [:create, :publication]

  validates :replaced_by_procedure_id, presence: true, if: :closing_reason_internal_procedure?
  validate :check_replaced_by_procedure_not_self, if: :closing_reason_internal_procedure?

  validates :duree_conservation_dossiers_dans_ds, allow_nil: false,
                                                  numericality: {
                                                    only_integer: true,
                                                    greater_than_or_equal_to: 1,
                                                    less_than_or_equal_to: :max_duree_conservation_dossiers_dans_ds,
                                                  }
  validates :max_duree_conservation_dossiers_dans_ds, allow_nil: false,
                                                  numericality: {
                                                    only_integer: true,
                                                    greater_than_or_equal_to: 1,
                                                    less_than_or_equal_to: Expired::MAX_DOSSIER_RENTENTION_IN_MONTH,
                                                  }

  validates_with MonAvisEmbedValidator, on: :publication

  validate :validates_associated_draft_revision_with_context
  validates_associated :initiated_mail, on: :publication
  validates_associated :received_mail, on: :publication
  validates_associated :closed_mail, on: :publication
  validates_associated :refused_mail, on: :publication
  validates_associated :without_continuation_mail, on: :publication
  validates_associated :re_instructed_mail, on: :publication
  validates_associated :attestation_acceptation_template, on: :publication, if: -> { attestation_acceptation_template&.activated? }
  validates_associated :attestation_refus_template, on: :publication, if: -> { attestation_refus_template&.activated? }

  FILE_MAX_SIZE = 20.megabytes
  validates :notice, content_type: [
    "application/msword",
    "application/pdf",
    "application/vnd.ms-powerpoint",
    "application/vnd.oasis.opendocument.presentation",
    "application/vnd.oasis.opendocument.text",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "image/jpeg",
    "image/jpg",
    "image/png",
    "text/plain",
  ], size: { less_than: FILE_MAX_SIZE }, if: -> { new_record? || created_at > Date.new(2020, 2, 28) }

  validates :deliberation, content_type: [
    "application/msword",
    "application/pdf",
    "application/vnd.oasis.opendocument.text",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "image/jpeg",
    "image/jpg",
    "image/png",
    "text/plain",
  ], size: { less_than: FILE_MAX_SIZE }, if: -> { new_record? || created_at > Date.new(2020, 4, 29) }

  LOGO_MAX_SIZE = 5.megabytes
  validates :logo, content_type: ['image/png', 'image/jpg', 'image/jpeg'],
    size: { less_than: LOGO_MAX_SIZE },
    if: -> { new_record? || created_at > Date.new(2020, 11, 13) }

  validates :api_particulier_token, format: { with: /\A[A-Za-z0-9\-_=.]{15,}\z/ }, allow_blank: true
  validate :validate_auto_archive_on_in_the_future, if: :will_save_change_to_auto_archive_on?

  before_save :update_juridique_required
  after_save :extend_conservation_for_dossiers

  after_create :ensure_defaut_groupe_instructeur

  include AASM

  aasm whiny_persistence: true do
    state :brouillon, initial: true
    state :publiee
    state :close
    state :depubliee

    event :publish, before: :before_publish do
      transitions from: :brouillon, to: :publiee, after: :after_publish
      transitions from: :close, to: :publiee, after: :after_republish
      transitions from: :depubliee, to: :publiee, after: :after_republish
    end

    event :close, after: :after_close do
      transitions from: :publiee, to: :close
    end

    event :unpublish, after: :after_unpublish do
      transitions from: :publiee, to: :depubliee
    end
  end

  def enable_pro_connect_restriction!(level)
    update!(
      pro_connect_restriction: level,
      opendata: level == :all ? false : opendata,
      robots_indexable: level == :all ? false : robots_indexable
    )
  end

  def check_administrateur_minimal_presence(_object)
    if self.administrateurs.count <= 1
      raise ActiveRecord::RecordNotDestroyed.new("Cannot remove the last administrateur of procedure #{self.libelle} (#{self.id})")
    end
  end

  def dossiers_close_to_expiration
    dossiers.close_to_expiration.count
  end

  def canonical_procedure_child?(procedure)
    !canonical_procedure || canonical_procedure == procedure || canonical_procedure == procedure.canonical_procedure
  end

  def locked?
    publiee? || close? || depubliee?
  end

  def draft_changed?
    preload_draft_and_published_revisions
    !brouillon? && (types_de_champ_revision_changes.present? || ineligibilite_rules_revision_changes.present?)
  end

  def types_de_champ_revision_changes
    published_revision.compare_types_de_champ(draft_revision)
  end

  def ineligibilite_rules_revision_changes
    published_revision.compare_ineligibilite_rules(draft_revision)
  end

  def preload_draft_and_published_revisions
    revisions = []
    if !association(:published_revision).loaded? && published_revision_id.present?
      revisions.push(published_revision)
    end
    if !association(:draft_revision).loaded? && draft_revision_id.present?
      revisions.push(draft_revision)
    end
    ProcedureRevisionPreloader.new(revisions).all if !revisions.empty?
  end

  def accepts_new_dossiers?
    publiee? || brouillon?
  end

  def replaced_by_procedure?
    replaced_by_procedure_id.present?
  end

  def dossier_can_transition_to_en_construction?
    accepts_new_dossiers? || depubliee?
  end

  def expose_legacy_carto_api?
    module_api_carto&.use_api_carto? && module_api_carto&.migrated?
  end

  def declarative?
    declarative_with_state.present?
  end

  def declarative_accepte?
    declarative_with_state == Procedure.declarative_with_states.fetch(:accepte)
  end

  def declarative_en_instruction?
    declarative_with_state == Procedure.declarative_with_states.fetch(:en_instruction)
  end

  def self.declarative_attributes_for_select
    declarative_with_states.map do |state, _|
      [I18n.t("activerecord.attributes.#{model_name.i18n_key}.declarative_with_state/#{state}"), state]
    end
  end

  def feature_enabled?(feature)
    Flipper.enabled?(feature, self)
  end

  def organisation_name
    service&.nom || organisation
  end

  def self.active(id)
    publiees.find(id)
  end

  def whitelisted?
    whitelisted_at.present?
  end

  def hidden_as_template?
    hidden_at_as_template.present?
  end

  def hide_as_template!
    touch(:hidden_at_as_template)
  end

  def unhide_as_template!
    self.hidden_at_as_template = nil
    save
  end

  def total_dossier
    self.dossiers.state_not_brouillon.size
  end

  def passer_en_construction_email_template
    initiated_mail || Mails::InitiatedMail.default_for_procedure(self)
  end

  def passer_en_instruction_email_template
    received_mail || Mails::ReceivedMail.default_for_procedure(self)
  end

  def accepter_email_template
    closed_mail || Mails::ClosedMail.default_for_procedure(self)
  end

  def refuser_email_template
    refused_mail || Mails::RefusedMail.default_for_procedure(self)
  end

  def classer_sans_suite_email_template
    without_continuation_mail || Mails::WithoutContinuationMail.default_for_procedure(self)
  end

  def repasser_en_instruction_email_template
    re_instructed_mail || Mails::ReInstructedMail.default_for_procedure(self)
  end

  def email_template_for(state)
    case state
    when Dossier.states.fetch(:en_construction)
      passer_en_construction_email_template
    when Dossier.states.fetch(:en_instruction)
      passer_en_instruction_email_template
    when DossierOperationLog.operations.fetch(:repasser_en_instruction)
      repasser_en_instruction_email_template
    when Dossier.states.fetch(:accepte)
      accepter_email_template
    when Dossier.states.fetch(:refuse)
      refuser_email_template
    when Dossier.states.fetch(:sans_suite)
      classer_sans_suite_email_template
    else
      raise "Unknown dossier state: #{state}"
    end
  end

  def whitelist!
    touch(:whitelisted_at)
  end

  def mail_template_attestation_inconsistency_state(mail_type)
    case mail_type
    when :acceptation
      mail = closed_mail
      attestation = attestation_acceptation_template
    when :refus
      mail = refused_mail
      attestation = attestation_refus_template
    end

    return if mail.nil?

    tag_present = mail.body.to_s.include?('--lien attestation--')
    if attestation&.activated? && !tag_present
      :missing_tag
    elsif !attestation&.activated? && tag_present
      :extraneous_tag
    end
  end

  def missing_steps
    result = []

    if service.nil?
      result << :service
    end

    if service_siret_test?
      result << :service
    end

    if missing_instructeurs?
      result << :instructeurs
    end

    if missing_zones?
      result << :zones
    end

    result
  end

  def logo_url
    if logo.attached?
      logo_variant = logo.variant(resize_to_limit: [400, 400])
      logo_variant.key.present? ? logo_variant.processed.url : Rails.application.routes.url_helpers.url_for(logo)
    else
      ActionController::Base.helpers.image_url(PROCEDURE_DEFAULT_LOGO_SRC)
    end
  end

  def missing_instructeurs?
    !AssignTo.exists?(groupe_instructeur: groupe_instructeurs)
  end

  def missing_zones?
    if Rails.application.config.ds_zonage_enabled
      zones.empty?
    else
      false
    end
  end

  def service_siret_test?
    service&.siret == Service::SIRET_TEST
  end

  def revised?
    revisions.size > 2
  end

  def revisions_count
    # We start counting from the first revision after publication and we are not counting the draft (there is always one)
    revisions.size - 2
  end

  def instructeurs_self_management?
    instructeurs_self_management_enabled?
  end

  def groupe_instructeurs_but_defaut
    groupe_instructeurs - [defaut_groupe_instructeur]
  end

  def routing_champs
    active_revision.revision_types_de_champ_public.filter(&:used_by_routing_rules?).map(&:libelle)
  end

  def dossiers_count
    dossiers.count
  end

  def can_be_deleted_by_administrateur?
    brouillon? || dossiers.state_en_instruction.empty?
  end

  def can_be_deleted_by_manager?
    kept? && can_be_deleted_by_administrateur?
  end

  def discard_and_keep_track!(author)
    if brouillon?
      reset!
    elsif publiee?
      close!
    end

    dossiers.visible_by_administration.find_each do |dossier|
      dossier.hide_and_keep_track!(author, :procedure_removed)
    end

    discard!
  end

  def purge_discarded
    if dossiers.empty?
      destroy
    end
  end

  def self.purge_discarded
    discarded_expired.find_each do |p|
      p.purge_discarded
    rescue StandardError => e
      Sentry.capture_exception(e, extra: { procedure_id: p.id })
    end
  end

  def restore(author)
    if discarded? && undiscard
      dossiers.hidden_by_administration.find_each do |dossier|
        dossier.restore(author)
      end
    end
  end

  def average_dossier_weight
    if dossiers.termine.any?
      dossiers_sample = dossiers.termine.limit(100)
      total_size = Champ
        .includes(piece_justificative_file_attachments: :blob)
        .where(type: Champs::PieceJustificativeChamp.to_s, dossier: dossiers_sample)
        .sum('active_storage_blobs.byte_size')

      MIN_WEIGHT + total_size / dossiers_sample.length
    else
      nil
    end
  end

  def cnaf_enabled?
    api_particulier_sources['cnaf'].present?
  end

  def dgfip_enabled?
    api_particulier_sources['dgfip'].present?
  end

  def pole_emploi_enabled?
    api_particulier_sources['pole_emploi'].present?
  end

  def mesri_enabled?
    api_particulier_sources['mesri'].present?
  end

  def published_or_created_at
    published_at || created_at
  end

  def publiee_or_close?
    publiee? || close?
  end

  def self.tags
    unnest = Arel::Nodes::NamedFunction.new('UNNEST', [self.arel_table[:tags]])
    query = self.select(unnest.as('tags')).publiees.distinct.order('tags') # rubocop:disable Rails/OrderArguments
    self.connection.query(query.to_sql).flatten
  end

  def compute_dossiers_count
    now = Time.zone.now
    if now > (self.dossiers_count_computed_at || self.created_at) + DOSSIERS_COUNT_EXPIRING
      self.update(estimated_dossiers_count: self.dossiers.visible_by_administration.count,
                dossiers_count_computed_at: now)
    end
  end

  def update_juridique_required
    self.juridique_required ||= (cadre_juridique.present? || deliberation.attached?)
    true
  end

  def check_juridique
    if juridique_required? && (cadre_juridique.blank? && !deliberation.attached?)
      errors.add(:cadre_juridique, " : veuillez remplir le texte de loi ou la délibération")
    end
  end

  def check_replaced_by_procedure_not_self
    if replaced_by_procedure_id == id
      errors.add(:replaced_by_procedure_id, "ne peut pas être la procédure elle-même")
    end
  end

  def extend_conservation_for_dossiers
    return if !previous_changes.include?(:duree_conservation_dossiers_dans_ds)
    before, after = duree_conservation_dossiers_dans_ds_previous_change
    return if [before, after].any?(&:nil?)
    return if (after - before).negative?

    ResetExpiringDossiersJob.perform_later(self)
  end

  def ensure_defaut_groupe_instructeur
    if self.groupe_instructeurs.empty?
      gi = groupe_instructeurs.create(label: GroupeInstructeur::DEFAUT_LABEL)
      self.update(defaut_groupe_instructeur_id: gi.id)
    end
  end

  def create_generic_labels
    Label::GENERIC_LABELS.each do |label|
      Label.create(name: label[:name], color: label[:color], procedure_id: self.id)
    end
  end

  def update_labels_position(ordered_label_ids)
    label_ids_positions = ordered_label_ids.each.with_index.to_h
    Label.transaction do
      label_ids_positions.each do |label_id, position|
        Label.where(id: label_id).update(position:)
      end
    end
  end

  def used_by_routing_rules?(type_de_champ)
    type_de_champ.stable_id.in?(stable_ids_used_by_routing_rules)
  end

  # We need this to unfuck administrate + aasm
  def self.human_attribute_name(attribute, options = {})
    if attribute == :aasm_state
      'Statut'
    else
      super
    end
  end

  def toggle_routing
    update!(routing_enabled: self.groupe_instructeurs.active.many?)
  end

  def lien_dpo_email?
    lien_dpo.present? && lien_dpo.match?(/@/)
  end

  def dossier_for_preview(user)
    # Try to use a preview or a dossier filled by current user
    dossiers.where(for_procedure_preview: true).or(dossiers.visible_by_administration)
      .order(Arel.sql("CASE WHEN user_id = #{user.id} THEN 1 ELSE 0 END DESC,
                       CASE WHEN state = 'accepte' THEN 1 ELSE 0 END DESC,
                       CASE WHEN state = 'brouillon' THEN 0 ELSE 1 END DESC,
                       CASE WHEN for_procedure_preview = True THEN 1 ELSE 0 END DESC,
                       id DESC")) \
      .first
  end

  def reset_closing_params
    update!(closing_reason: nil, closing_details: nil, replaced_by_procedure_id: nil, closing_notification_brouillon: false, closing_notification_en_cours: false)
  end

  def monavis_embed_html_source(source)
    monavis_embed.gsub('nd_source=button', "nd_source=#{source}").gsub('<a ', '<a target="_blank" rel="noopener noreferrer" ')
  end

  def mail_templates
    [
      self.passer_en_construction_email_template,
      self.passer_en_instruction_email_template,
      self.accepter_email_template,
      self.refuser_email_template,
      self.classer_sans_suite_email_template,
      self.repasser_en_instruction_email_template,
    ]
  end

  def disallow_expert_review?
    !allow_expert_review?
  end

  def attestation_templates_v2_for(kind)
    public_send("attestation_#{kind}_templates_v2")
  end

  def published_attestation_template_for(kind)
    public_send("attestation_#{kind}_template")
  end

  private

  def stable_ids_used_by_routing_rules
    @stable_ids_used_by_routing_rules ||= groupe_instructeurs.flat_map { _1.routing_rule&.sources }.compact.uniq
  end

  def published_revisions_types_de_champ(parent: nil, with_header_section: false)
    # all published revisions
    revision_ids = revisions.ids - [draft_revision_id]
    # fetch all parent types de champ
    parent_ids = if parent.present?
      ProcedureRevisionTypeDeChamp
        .where(revision_id: revision_ids)
        .joins(:type_de_champ)
        .where(type_de_champ: { stable_id: parent.stable_id })
        .ids
    end

    # fetch all type_de_champ.stable_id for all the revisions expect draft
    # and for each stable_id take the bigger (more recent) type_de_champ.id
    types_de_champ_scope = with_header_section ? TypeDeChamp.with_header_section : TypeDeChamp.fillable
    recent_ids = types_de_champ_scope
      .joins(:revision_types_de_champ)
      .where(revision_types_de_champ: { revision_id: revision_ids, parent_id: parent_ids })
      .group(:stable_id).select('MAX(types_de_champ.id)')

    # fetch the more recent procedure_revision_types_de_champ
    # which includes recents_ids
    recents_prtdc = ProcedureRevisionTypeDeChamp
      .unscope(:eager_load)
      .where(type_de_champ_id: recent_ids)
      .where.not(revision_id: draft_revision_id)
      .group(:type_de_champ_id)
      .select('MAX(id)')

    TypeDeChamp
      .joins(:revision_types_de_champ)
      .where(revision_types_de_champ: { id: recents_prtdc }).then do |relation|
        if feature_enabled?(:export_order_by_revision) # Fonds Verts, en attente d'exports personnalisables
          relation.order(:private, 'revision_types_de_champ.revision_id': :desc, position: :asc)
        else
          relation.order(:private, :position, 'revision_types_de_champ.revision_id': :desc)
        end
      end
  end

  def validates_associated_draft_revision_with_context
    return if draft_revision.blank?
    return if draft_revision.validate(validation_context)

    draft_revision.errors.map { errors.import(_1) }
  end

  def validate_auto_archive_on_in_the_future
    return if auto_archive_on.nil?
    return if auto_archive_on.future?

    errors.add(:auto_archive_on, 'doit être dans le futur')
  end
end
