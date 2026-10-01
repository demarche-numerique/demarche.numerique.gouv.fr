# frozen_string_literal: true

# Where a brouillon stands on its way to removal (#13915):
#
#   warned  notified of its expiration; removal_due_at is the destruction
#           date, a notice period after the notice
#   hidden  trashed; removal_due_at is the purge date, two weeks after the
#           first hiding. A warned brouillon put in the trash is hidden.
#
# The expiration cron destroys a brouillon rather than trashing it, but a
# hiding by expiration still counts, as it does for the legacy purge.
#
# A NULL stage means the legacy columns still rule the dossier. The stage
# follows the notice and the hiding dates in the statement writing them:
# through the before_save for trash, restore, conservation extension and
# procedure reset; in SQL for the two writes skipping the callbacks, the
# notice cron (warn_removal!) and the autosave
# (update_columns_and_unwarn).
module DossierRemovalConcern
  extend ActiveSupport::Concern

  # A row is warned only while it is a brouillon out of the trash.
  WARNABLE = "state = 'brouillon' AND hidden_by_user_at IS NULL AND hidden_by_expired_at IS NULL"

  # Cancelling the notice takes a warned row out of its stage, and leaves a
  # trashed one alone. Both expressions read the row before the update.
  UNWARN_ASSIGNMENTS = <<~SQL.squish
    removal_stage = CASE WHEN removal_stage = 'warned' THEN NULL ELSE removal_stage END,
    removal_due_at = CASE WHEN removal_stage = 'warned' THEN NULL ELSE removal_due_at END
  SQL

  # The notice cron's write over the current relation: the notice date on
  # every row, and the warned stage, due a notice period later, only on the
  # rows still brouillon and out of the trash, since they were loaded before.
  WARN_ASSIGNMENTS = <<~SQL.squish
    brouillon_close_to_expiration_notice_sent_at = :noticed_at,
    removal_stage = CASE WHEN #{WARNABLE} THEN 'warned' ELSE removal_stage END,
    removal_due_at = CASE WHEN #{WARNABLE} THEN :due_at ELSE removal_due_at END
  SQL

  included do
    enum :removal_stage, { warned: 'warned', hidden: 'hidden' }, prefix: :removal

    before_save :follow_removal, if: -> {
      will_save_change_to_state? ||
        will_save_change_to_hidden_by_user_at? ||
        will_save_change_to_hidden_by_expired_at? ||
        will_save_change_to_brouillon_close_to_expiration_notice_sent_at?
    }
  end

  class_methods do
    def warn_removal!(noticed_at)
      update_all([WARN_ASSIGNMENTS, { noticed_at:, due_at: noticed_at + Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks }])
    end
  end

  # A brouillon hidden twice keeps its first purge date.
  def trash_purge_at
    return unless brouillon?

    [hidden_by_user_at, hidden_by_expired_at].compact.min&.+(Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks)
  end

  def notice_deletion_at
    return unless brouillon?

    brouillon_close_to_expiration_notice_sent_at&.+(Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks)
  end

  # update_columns cancelling the notice, which takes a warned brouillon out
  # of its stage in the same statement: read in SQL, so that a stage written
  # since the dossier was loaded is seen, and a trashed brouillon stays hidden.
  def update_columns_and_unwarn(attributes)
    self.class.where(id:).update_all("#{self.class.sanitize_sql_for_assignment(attributes)}, #{UNWARN_ASSIGNMENTS}")

    attributes = attributes.merge(removal_stage: nil, removal_due_at: nil) if removal_warned?
    assign_attributes(attributes)
    clear_attribute_changes(attributes.keys)
  end

  private

  def follow_removal
    if (purge_at = trash_purge_at)
      self.removal_stage, self.removal_due_at = :hidden, purge_at
    elsif (deletion_at = notice_deletion_at)
      self.removal_stage, self.removal_due_at = :warned, deletion_at
    else
      self.removal_stage, self.removal_due_at = nil, nil
    end
  end
end
