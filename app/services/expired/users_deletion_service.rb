# frozen_string_literal: true

class Expired::UsersDeletionService < Expired::MailRateLimiter
  INACTIVITY_CLOCK = Arel.sql("COALESCE(users.current_sign_in_at, users.created_at)")
  NOTICE_SENT_AT = User.arel_table[:inactive_close_to_expiration_notice_sent_at]

  def process_expired
    # we are working on two dataset because we apply two incompatible join on the same query
    #   inner join on users not having dossier.en_instruction [so we do not destroy users with dossiers.en_instruction]
    #   outer join on users not having dossier at all [so we destroy users without dossiers]
    [expired_users_without_dossiers, expired_users_with_dossiers].each do |expired_segment|
      reporting_errors { delete_notified_users(expired_segment) }
      reporting_errors { send_inactive_close_to_expiration_notice(expired_segment) }
    end
  end

  private

  # rubocop:disable DS/Unscoped
  def send_inactive_close_to_expiration_notice(users)
    user_ids = to_notify_only(users).pluck(:id)

    notifiable(user_ids).find_each do |user|
      send_with_delay(UserMailer.notify_inactive_close_to_deletion(user))
    end

    User.unscoped.where(id: user_ids).update_all(inactive_close_to_expiration_notice_sent_at: Time.zone.now.utc)
  end
  # rubocop:enable DS/Unscoped

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
  end

  def expired_users_without_dossiers
    expired_users.where.missing(:dossiers)
  end

  def expired_users
    User.unscoped
      .where.missing(:expert, :instructeur, :administrateur)
      .where(INACTIVITY_CLOCK.lteq(Expired::INACTIVE_USER_RETENTION_IN_YEAR.years.ago))
  end
  # rubocop:enable DS/Unscoped

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
