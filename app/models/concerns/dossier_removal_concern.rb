# frozen_string_literal: true

# Where a dossier stands on its way to removal (#13915):
#
#   retained  kept; removal_due_at is the notice date (expired_at − 2 weeks)
#   warned    notified; removal_due_at is the destruction date (= expired_at)
#   hidden    trashed; removal_due_at is the purge date (hiding + 2 weeks)
#
# Only the dossiers in REMOVAL_MANAGED_STATES carry a stage: a dossier gets
# `retained` when it enters one of them and loses its stage when it leaves,
# in the statement writing the state. A NULL stage means the legacy columns
# (expired_at, the notice dates, hidden_by_*_at) still rule the dossier.
#
# Every other write of the stage is an event (warn_removal!,
# restart_removal!, hide_removal!, restore_removal!, refresh_removal!) going
# through move_removal!, a compare-and-set which only follows
# REMOVAL_TRANSITIONS. The legacy columns are still written alongside.
module DossierRemovalConcern
  extend ActiveSupport::Concern

  class InvalidRemovalMove < StandardError; end

  REMOVAL_MANAGED_STATES = ['brouillon'].freeze

  # from => the stages it may move to. retained → retained refreshes the due
  # date when the brouillon is edited or its conservation extended.
  REMOVAL_TRANSITIONS = {
    'retained' => ['retained', 'warned', 'hidden'].freeze,
    'warned' => ['retained', 'hidden'].freeze,
    'hidden' => ['retained', 'warned'].freeze,
  }.freeze

  # Stages that an activity of the usager (edit, extension) takes back to
  # retained. A trashed brouillon only leaves the trash by a restore.
  REMOVAL_RESTARTABLE = ['retained', 'warned'].freeze

  included do
    enum :removal_stage, {
      retained: 'retained',
      warned: 'warned',
      hidden: 'hidden',
    }, prefix: :removal

    # The enum bang methods would write the stage without the compare-and-set.
    removal_stages.each_key { undef_method :"removal_#{it}!" }

    before_save :follow_removal_ownership, if: -> { new_record? || will_save_change_to_state? }
  end

  class_methods do
    # The only place computing the notice date of a brouillon in Ruby.
    def removal_notice_at(expired_at) = expired_at - Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks

    # Compare-and-set over the current relation: only the rows still in one of
    # the `from` stages move to `to`, with `columns` written alongside. A row
    # moved in the meantime (a brouillon edited after the cron selected it) is
    # left alone. Returns the ids actually moved.
    def move_removal!(from:, to:, expired_at: nil, due_at: nil, **columns)
      assignments = sanitize_sql_for_assignment(removal_move_columns(from:, to:, expired_at:, due_at:, **columns))
      condition = sanitize_sql_array(["dossiers.removal_stage IN (?)", Array(from).map(&:to_s)])

      with_connection do |connection|
        connection.select_values(<<~SQL.squish, "Dossier Move Removal")
          UPDATE dossiers SET #{assignments}
          WHERE #{condition} AND dossiers.id IN (#{reselect(:id).to_sql})
          RETURNING dossiers.id
        SQL
      end
    end

    # The cron notice, J-14: the brouillon is destroyed two weeks after `at`,
    # the date the mail announces.
    def warn_removal!(at)
      expired_at = at + Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks
      move_removal!(from: :retained, to: :warned, expired_at:, brouillon_close_to_expiration_notice_sent_at: at)
    end

    # What the stage and its due date become, with the columns written along.
    # The due date follows from expired_at, except for the trash.
    def removal_move_columns(from:, to:, expired_at:, due_at:, **columns)
      to = to.to_s
      Array(from).each do |source|
        if REMOVAL_TRANSITIONS.fetch(source.to_s, []).exclude?(to)
          raise InvalidRemovalMove, "#{source} -> #{to}"
        end
      end

      case to
      when 'retained'
        columns.merge(expired_at:, removal_due_at: removal_notice_at(expired_at))
      when 'warned'
        columns.merge(expired_at:, removal_due_at: expired_at)
      when 'hidden'
        columns.merge(removal_due_at: due_at || raise(ArgumentError, "due_at: is required to hide"))
      end.merge(removal_stage: to)
    end
  end

  def removal_managed? = removal_stage.present?

  # Whether the removal of a dossier in this state is the stage's business.
  # A managed state without a stage is a dossier the backfill has not reached
  # yet: it still expires through the legacy columns.
  def removal_managed_state? = state.in?(REMOVAL_MANAGED_STATES)

  # Moves this dossier if it is still in one of the `from` stages in the
  # database, and writes `columns` with it. Returns whether it moved; when it
  # did not, nothing was written: whoever moved the row owns it.
  def move_removal!(from:, to:, expired_at: nil, due_at: nil, **columns)
    values = self.class.removal_move_columns(from:, to:, expired_at:, due_at:, **columns)
    from = Array(from).map(&:to_s)

    # The row as it was loaded says whether the move is worth a statement at
    # all: it is not in a `from` stage (an annotation on a warned brouillon),
    # or it is already where the move would put it with the values it would
    # write (a save that did not touch the expiration, an extension the save
    # before it already applied).
    return false if from.exclude?(removal_stage)
    return true if removal_stage == values[:removal_stage] && values.all? { |name, value| read_attribute(name) == value }

    moved = self.class.where(id:, removal_stage: from).update_all(values) == 1

    if moved
      values.each do |name, value|
        write_attribute(name, value)
        clear_attribute_change(name)
      end
    end

    moved
  end

  # Activity of the usager restarts the clock: an edit or an extension takes a
  # retained or warned brouillon back to retained, expiring a full
  # conservation period after its last edit, and cancels the notice.
  def restart_removal!(expired_at: expiration_date_with_extension, **columns)
    move_removal!(from: REMOVAL_RESTARTABLE, to: :retained, expired_at:, brouillon_close_to_expiration_notice_sent_at: nil, **columns)
  end

  # A save moved expired_at of a retained brouillon (its reference date is
  # updated_at until the first edit, and an annotation bumps it): follow it
  # inside the stage. A warned or hidden brouillon keeps the date of its
  # stage.
  def refresh_removal!(expired_at: expiration_date_with_extension, **columns)
    move_removal!(from: :retained, to: :retained, expired_at:, **columns)
  end

  # Trashed by the usager (or automatically): purged two weeks later. This
  # is the brouillon rule; a terminé needs both the usager and the
  # administration to have trashed it, and is not managed here.
  # A brouillon already hidden keeps its first purge date.
  def hide_removal!(at)
    move_removal!(from: REMOVAL_RESTARTABLE, to: :hidden, due_at: at + Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks)
  end

  # Out of the trash, and only once no hiding flag is left: a brouillon the
  # usager took back while the expiration still hides it stays there. As
  # before the stage existed, a brouillon warned before its trash is warned
  # again, with the date its notice announced.
  def restore_removal!
    return false if !removal_hidden? || hidden_by_user? || hidden_by_expired?

    to = brouillon_close_to_expiration_notice_sent_at.present? ? :warned : :retained
    move_removal!(from: :hidden, to:, expired_at: expiration_date)
  end

  private

  # Entering a managed state starts at retained (the due date is written with
  # expired_at); leaving it drops the stage, forced into the statement even
  # when the stage in memory is already nil (a dossier loaded before a
  # backfill gave it one).
  def follow_removal_ownership
    managed = removal_managed_state?
    return if managed == (persisted? && state_in_database.in?(REMOVAL_MANAGED_STATES))

    self.removal_stage = managed ? :retained : nil
    self.removal_due_at = nil
    removal_stage_will_change!
    removal_due_at_will_change!
  end
end
