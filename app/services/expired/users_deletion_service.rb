# frozen_string_literal: true

class Expired::UsersDeletionService < Expired::MailRateLimiter
  INACTIVITY_CLOCK = Arel.sql("COALESCE(users.current_sign_in_at, users.created_at)")
  NOTICE_SENT_AT = User.arel_table[:inactive_close_to_expiration_notice_sent_at]

  def process_expired
    [expired_users_without_dossiers, expired_users_with_dossiers].each do |expired_segment|
      reporting_errors { delete_notified_users(expired_segment) }
      reporting_errors { send_inactive_close_to_expiration_notice(expired_segment) }
    end
  end

  private

  def send_inactive_close_to_expiration_notice(users)
    user_ids = to_notify_only(users).pluck(:id)

    notifiable(user_ids).find_each do |user|
      send_with_delay(UserMailer.notify_inactive_close_to_deletion(user))
    end

    users.where(id: user_ids).update_all(inactive_close_to_expiration_notice_sent_at: Time.zone.now.utc)
  end

  def delete_notified_users(users)
    only_notified(users).pluck(:id).each do |user_id|
      user = only_notified(users).find_by(id: user_id)
      next if user.nil?

      user.delete_and_keep_track_dossiers_also_delete_user(nil, reason: :user_expired)
    rescue => e
      Sentry.capture_exception(e, tags: { user: user_id })
    end
  end

  def expired_users_with_dossiers
    expired_users.where.not(owned_by_user(Dossier.state_en_instruction))
  end

  def expired_users_without_dossiers
    expired_users.where.not(owned_by_user(Dossier))
  end

  # NOT EXISTS rather than where.missing, which Postgres cannot plan as an anti-join.
  # rubocop:disable DS/Unscoped
  def expired_users
    User.unscoped
      .where.not(owned_by_user(Expert))
      .where.not(owned_by_user(Instructeur))
      .where.not(owned_by_user(Administrateur))
      .where(INACTIVITY_CLOCK.lteq(Expired::INACTIVE_USER_RETENTION_IN_YEAR.years.ago))
  end
  # rubocop:enable DS/Unscoped

  def owned_by_user(relation)
    relation.where(relation.arel_table[:user_id].eq(User.arel_table[:id])).arel.exists
  end

  # BalancerDeliveryMethod drops any mail to an address the user never verified.
  # rubocop:disable DS/Unscoped
  def notifiable(user_ids)
    User.unscoped.where(id: user_ids).where.not(email_verified_at: nil)
  end
  # rubocop:enable DS/Unscoped

  def to_notify_only(users)
    users.where(NOTICE_SENT_AT.eq(nil).or(NOTICE_SENT_AT.lteq(INACTIVITY_CLOCK)))
      .order(INACTIVITY_CLOCK)
      .limit(daily_limit) # ensure to not send too much email
  end

  def only_notified(users)
    users.where(NOTICE_SENT_AT.gt(INACTIVITY_CLOCK))
      .where.not(inactive_close_to_expiration_notice_sent_at: Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.ago..)
      .limit(daily_limit) # event if we do not send email, avoid to destroy 800k user in one batch
  end

  def daily_limit
    (ENV['EXPIRE_USER_DELETION_JOB_LIMIT'] || 10_000).to_i
  end

  def reporting_errors
    yield
  rescue => e
    Sentry.capture_exception(e)
  end
end
