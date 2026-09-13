# frozen_string_literal: true

class Expired::UsersDeletionService < Expired::MailRateLimiter
  def process_expired
    # we are working on two dataset because we apply two incompatible join on the same query
    #   inner join on users not having dossier.en_instruction [so we do not destroy users with dossiers.en_instruction]
    #   outer join on users not having dossier at all [so we destroy users without dossiers]
    [expired_users_without_dossiers, expired_users_with_dossiers].each do |expired_segment|
      delete_notified_users(expired_segment)
      send_inactive_close_to_expiration_notice(expired_segment)
    end
  end

  private

  # in case of perf downside :
  #  consider using perform_all_later
  #  consider changing notify_inactive_close_to_deletion method, taking a user_id, and updating inactive_close_to_expiration_notice_sent_at
  def send_inactive_close_to_expiration_notice(users)
    user_ids = to_notify_only(users).pluck(:id)
    user_ids.each do |user_id|
      send_with_delay(UserMailer.notify_inactive_close_to_deletion(User.find(user_id)))
    end
    User.where(id: user_ids).update_all(inactive_close_to_expiration_notice_sent_at: Time.zone.now.utc)
  end

  def delete_notified_users(users)
    user_ids = only_notified(users).pluck(:id)
    user_ids.each do |user_id|
      user = User.find(user_id)
      begin
        user.delete_and_keep_track_dossiers_also_delete_user(nil, reason: :user_expired)
      rescue => e
        Sentry.capture_exception(e, tags: { user: user.id })
      end
    end
  end

  # rubocop:disable DS/Unscoped
  def expired_users_with_dossiers
    dossiers = Dossier.arel_table
    users = User.arel_table

    expired_users
      .joins(
      users.join(dossiers, Arel::Nodes::OuterJoin)
        .on(users[:id].eq(dossiers[:user_id])
        .and(dossiers[:state].eq(Dossier.states.fetch(:en_instruction))))
        .join_sources
    )
      .where(dossiers[:id].eq(nil))
      .group("users.id")
  end

  def expired_users_without_dossiers
    expired_users.where.missing(:dossiers)
  end

  def expired_users
    User.unscoped
      .where.missing(:expert, :instructeur, :administrateur)
      .where(current_sign_in_at: ..Expired::INACTIVE_USER_RETATION_IN_YEAR.years.ago)
  end
  # rubocop:enable DS/Unscoped

  def to_notify_only(users)
    users.where(inactive_close_to_expiration_notice_sent_at: nil)
      .limit(daily_limit) # ensure to not send too much email
  end

  def only_notified(users)
    users.where.not(inactive_close_to_expiration_notice_sent_at: Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.ago..)
      .limit(daily_limit) # event if we do not send email, avoid to destroy 800k user in one batch
  end

  def daily_limit
    (ENV['EXPIRE_USER_DELETION_JOB_LIMIT'] || 10_000).to_i
  end
end
