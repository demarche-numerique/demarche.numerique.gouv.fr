# frozen_string_literal: true

module DossierRebaseConcern
  RACE_CONDITION_DELAY = 30.seconds

  extend ActiveSupport::Concern

  def rebase!
    ProcedureRevisionPreloader.new([procedure.published_revision, revision].compact).all
    return if procedure.published_revision.blank?
    return if !can_rebase?

    transaction { rebase }
  end

  def rebase_later
    DossierRebaseJob.set(wait: RACE_CONDITION_DELAY).perform_later(self)
  end

  def can_rebase?
    procedure.published_revision.present? && revision != procedure.published_revision && !termine?
  end

  def pending_changes
    procedure.published_revision.present? ? revision.compare_types_de_champ(procedure.published_revision) : []
  end

  private

  def rebase
    # revision we are rebasing to
    target_revision = procedure.published_revision

    changed_stable_ids_by_op = pending_changes
      .group_by(&:op)
      .transform_values { _1.map(&:stable_id) }
    updated_stable_ids = changed_stable_ids_by_op.fetch(:update, [])
    added_stable_ids = changed_stable_ids_by_op.fetch(:add, [])

    # update dossier revision
    update_column(:revision_id, target_revision.id)

    # mark updated champ_data as rebased
    champ_data.where(stable_id: updated_stable_ids).update_all(rebased_at: Time.zone.now)

    # add rows for new repetitions
    target_revision
      .types_de_champ
      .filter { _1.repetition? && _1.stable_id.in?(added_stable_ids) && (_1.mandatory? || _1.private?) }
      .each do |type_de_champ|
        self.champ_data << type_de_champ.build_champ_data(row_id: ULID.generate, rebased_at: Time.zone.now)
      end
  end
end
