# frozen_string_literal: true

class BatchOperation < ApplicationRecord
  BATCH_SELECTION_LIMIT = 500

  enum :operation, {
    accepter: 'accepter',
    refuser: 'refuser',
    classer_sans_suite: 'classer_sans_suite',
    archiver: 'archiver',
    desarchiver: 'desarchiver',
    follow: 'follow',
    passer_en_instruction: 'passer_en_instruction',
    repousser_expiration: 'repousser_expiration',
    repasser_en_construction: 'repasser_en_construction',
    restaurer: 'restaurer',
    unfollow: 'unfollow',
    supprimer: 'supprimer',
    create_avis: 'create_avis',
    create_commentaire: 'create_commentaire',
    restaurer_repousser_expiration: 'restaurer_repousser_expiration',
  }

  has_many :dossiers, dependent: :nullify
  has_many :dossier_operations, class_name: 'DossierBatchOperation', dependent: :destroy
  has_many :groupe_instructeurs, through: :dossier_operations
  belongs_to :instructeur

  store_accessor :payload, :motivation, :justificatif_motivation, :emails, :introduction, :question_label, :introduction_file, :confidentiel, :body, :piece_jointe, :statut, :mark_as_pending_response

  validates :operation, presence: true

  before_create :build_operations

  RETENTION_DURATION = 4.hours
  MAX_DUREE_GENERATION = 24.hours

  scope :stale, lambda {
    where.not(finished_at: nil)
      .where(updated_at: ...(Time.zone.now - RETENTION_DURATION))
  }

  scope :stuck, lambda {
    where(finished_at: nil)
      .where(updated_at: ...(Time.zone.now - MAX_DUREE_GENERATION))
  }

  def dossiers_safe_scope(dossier_ids = self.dossier_ids)
    query = instructeur
      .dossiers
      .where(id: dossier_ids)
    case operation
    when BatchOperation.operations.fetch(:archiver) then
      query.visible_by_administration.not_archived.state_termine
    when BatchOperation.operations.fetch(:desarchiver) then
      query.visible_by_administration.archived.state_termine
    when BatchOperation.operations.fetch(:passer_en_instruction) then
      query.visible_by_administration.state_en_construction
    when BatchOperation.operations.fetch(:accepter) then
      query.visible_by_administration.state_en_instruction
    when BatchOperation.operations.fetch(:refuser) then
      query.visible_by_administration.state_en_instruction
    when BatchOperation.operations.fetch(:classer_sans_suite) then
      query.visible_by_administration.state_en_instruction
    when BatchOperation.operations.fetch(:follow) then
      query.visible_by_administration.without_followers.en_cours
    when BatchOperation.operations.fetch(:repousser_expiration) then
      query.visible_by_administration.termine_or_en_construction_close_to_expiration
    when BatchOperation.operations.fetch(:repasser_en_construction) then
      query.visible_by_administration.state_en_instruction
    when BatchOperation.operations.fetch(:unfollow) then
      query.visible_by_administration.with_followers.en_cours
    when BatchOperation.operations.fetch(:supprimer) then
      query.visible_by_administration.state_termine
    when BatchOperation.operations.fetch(:restaurer) then
      query.hidden_by_administration
    when BatchOperation.operations.fetch(:create_avis) then
      query.visible_by_administration.state_not_termine
    when BatchOperation.operations.fetch(:create_commentaire) then
      query.visible_by_administration
    when BatchOperation.operations.fetch(:restaurer_repousser_expiration) then
      query.hidden_by_expired
    end
  end

  def enqueue_all
    touch(:run_at)
    dossiers_safe_scope
      .map { |dossier| BatchOperationProcessOneJob.perform_later(self, dossier) }
  end

  def process_one(dossier)
    case operation
    when BatchOperation.operations.fetch(:archiver)
      dossier.archiver!(instructeur)
    when BatchOperation.operations.fetch(:desarchiver)
      dossier.desarchiver!
    when BatchOperation.operations.fetch(:passer_en_instruction)
      dossier.passer_en_instruction!(instructeur: instructeur)
    when BatchOperation.operations.fetch(:accepter)
      dossier.accepter!(instructeur: instructeur, motivation: motivation, justificatif: justificatif_motivation)
    when BatchOperation.operations.fetch(:refuser)
      dossier.refuser!(instructeur: instructeur, motivation: motivation, justificatif: justificatif_motivation)
    when BatchOperation.operations.fetch(:classer_sans_suite)
      dossier.classer_sans_suite!(instructeur: instructeur, motivation: motivation, justificatif: justificatif_motivation)
    when BatchOperation.operations.fetch(:follow)
      instructeur.follow(dossier)
    when BatchOperation.operations.fetch(:repousser_expiration)
      dossier.extend_conservation(1.month)
    when BatchOperation.operations.fetch(:repasser_en_construction)
      dossier.repasser_en_construction!(instructeur: instructeur)
    when BatchOperation.operations.fetch(:unfollow)
      instructeur.unfollow(dossier)
    when BatchOperation.operations.fetch(:supprimer)
      dossier.hide_and_keep_track!(instructeur, :instructeur_request)
    when BatchOperation.operations.fetch(:restaurer)
      dossier.restore(instructeur)
    when BatchOperation.operations.fetch(:create_avis)
      CreateAvisService.call(
        dossier: dossier,
        instructeur_or_expert: instructeur,
        batch: true,
        params: {
          emails: emails || [],
          introduction: introduction,
          introduction_file: introduction_file,
          confidentiel: confidentiel,
          invite_linked_dossiers: payload['invite_linked_dossiers'],
          question_label: question_label,
        }.with_indifferent_access
      )
    when BatchOperation.operations.fetch(:create_commentaire)
      commentaire = CommentaireService.create(instructeur, dossier, { email: dossier.user.email, body:, piece_jointe: })
      dossier.flag_as_pending_response!(commentaire) if mark_as_pending_response && commentaire.errors.empty?
    when BatchOperation.operations.fetch(:restaurer_repousser_expiration)
      dossier.extend_conservation_and_restore(1.month, instructeur)
    end
  end

  def track_processed_dossier(success, dossier)
    dossiers.delete(dossier)

    if success
      dossier_operation(dossier).done!
    else
      dossier_operation(dossier).fail!
    end
  end

  def finalize_if_complete!
    return if dossiers.exists?

    updated_rows = self.class
      .where(id:, finished_at: nil)
      .update_all(finished_at: Time.current, updated_at: Time.current)

    if updated_rows == 1
      # we are the worker what the "win" the finished state
      after_all_processed
    end
  end

  # when an instructeur want to create a batch from his interface,
  #   another one might have run something on one of the dossier
  #   we use this approach to create a batch with given dossiers safely
  def self.safe_create!(params)
    transaction do
      instance = new(params)
      instance.dossiers = instance.dossiers_safe_scope(params[:dossier_ids])
        .not_having_batch_operation
      if instance.dossiers.present?
        instance.save!
        BatchOperationEnqueueAllJob.perform_later(instance)
        instance
      end
    end
  end

  def total_count
    dossier_operations.size
  end

  def success_count
    dossier_operations.success.size
  end

  def errors?
    dossier_operations.error.present?
  end

  def finished_at
    dossiers.empty? ? super : nil
  end

  def seen!
    update!(seen_at: Time.zone.now)
  end

  def finished_unseen?
    finished_at.present? && seen_at.blank?
  end

  def after_all_processed
    return unless create_avis?

    dossiers = Dossier.joins(:dossier_batch_operations)
      .where(dossier_batch_operations: {
        batch_operation_id: id,
        state: :success,
      })

    avis = Avis
      .includes(experts_procedure: :expert)
      .where(dossier: dossiers)

    avis.group_by { |a| a.experts_procedure.expert }
      .each do |expert, expert_avis|
      if should_notify?(expert_avis)
        expert.user.invite_expert_and_send_avis!(expert_avis)
      end
    end
  end

  private

  def dossier_operation(dossier)
    dossier_operations.find_by!(dossier:)
  end

  def build_operations
    dossier_operations.build(dossiers.map { { dossier: _1 } })
  end

  def should_notify?(expert_avis)
    experts_procedure = expert_avis.first.experts_procedure
    experts_procedure&.notify_on_new_avis?
  end
end
