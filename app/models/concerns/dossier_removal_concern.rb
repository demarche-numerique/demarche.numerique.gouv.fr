# frozen_string_literal: true

# Where a brouillon stands on its way to removal (#13915). Only the trash so far:
#
#   hidden  trashed; removal_due_at is the purge date, two weeks after the
#           first hiding
#
# The expiration cron destroys a brouillon rather than trashing it, but a
# hiding by expiration still counts, as it does for the legacy purge.
#
# A NULL stage means the legacy columns still rule the dossier. The stage
# follows the hiding dates in the statement writing them, whichever path
# writes them: trash, restore, conservation extension, procedure reset.
module DossierRemovalConcern
  extend ActiveSupport::Concern

  included do
    enum :removal_stage, { hidden: 'hidden' }, prefix: :removal

    scope :trash_purge_due, -> { removal_hidden.where(removal_due_at: ...Time.zone.now) }

    before_save :follow_trash, if: -> { will_save_change_to_state? || will_save_change_to_hidden_by_user_at? || will_save_change_to_hidden_by_expired_at? }
  end

  # A brouillon hidden twice keeps its first purge date.
  def trash_purge_at
    return unless brouillon?

    [hidden_by_user_at, hidden_by_expired_at].compact.min&.+(Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks)
  end

  private

  def follow_trash
    self.removal_due_at = trash_purge_at
    self.removal_stage = removal_due_at && :hidden
  end
end
