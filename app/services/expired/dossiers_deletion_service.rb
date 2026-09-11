# frozen_string_literal: true

class Expired::DossiersDeletionService < Expired::MailRateLimiter
  BROUILLON_DELETION_EMAILS_LIMIT_PER_DAY = ENV.fetch("BROUILLON_DELETION_EMAILS_LIMIT_PER_DAY", 10_000).to_i
  BROUILLON_WITHOUT_NOTICE_DELETION_LIMIT_PER_DAY = ENV.fetch("BROUILLON_WITHOUT_NOTICE_DELETION_LIMIT_PER_DAY", 20_000).to_i
  TERMINE_NOTICES_LIMIT_PER_DAY = ENV.fetch("TERMINE_NOTICES_LIMIT_PER_DAY", 50_000).to_i
  TERMINE_DELETION_LIMIT_PER_DAY = ENV.fetch("TERMINE_DELETION_LIMIT_PER_DAY", 50_000).to_i
  # Termine dossiers are flagged or hidden, then mailed, batch by batch: what a
  # failure mid-run can lose is bounded to one batch (a retry starts over from
  # the scopes, which no longer match the dossiers already flagged or hidden).
  # A batch grows past this size rather than splitting a user's dossiers.
  TERMINE_BATCH_SIZE = 1000

  def process_never_touched_dossiers_brouillon; delete_never_touched_brouillons; end

  def process_expired_dossiers_brouillon
    send_brouillon_expiration_notices
    delete_expired_brouillons_and_notify
    delete_expired_brouillons_without_notice
  end

  def process_expired_dossiers_termine
    send_termine_expiration_notices
    delete_expired_termine_and_notify
    update_notifications_dossiers_termine
  end

  def send_brouillon_expiration_notices
    dossiers_close_to_expiration = Dossier
      .brouillon_close_to_expiration
      .without_brouillon_expiration_notice_sent
      .order(:expired_at)
      .limit(BROUILLON_DELETION_EMAILS_LIMIT_PER_DAY)

    user_notifications = group_by_user_email(dossiers_close_to_expiration)

    user_notifications.each do |(email, dossiers)|
      all_user_dossiers = all_user_dossiers_brouillon_close_to_expiration(dossiers.first.user).to_a
      mail = DossierMailer.notify_brouillon_near_deletion(
        all_user_dossiers,
        email
      )

      send_with_delay(mail)
      Dossier.where(id: all_user_dossiers.map(&:id)).update_all(brouillon_close_to_expiration_notice_sent_at: Time.zone.now)
      Dossier.where(id: all_user_dossiers.map(&:id)).find_each(&:update_expired_at)
    end
  end

  def send_termine_expiration_notices
    # Ids first: the scope is a sparse filter over the 8M termine dossiers, and
    # iterating it with in_batches walked the primary key (#13816).
    ids_and_user_ids = Dossier.termine_close_to_expiration.without_termine_expiration_notice_sent
      .order(:expired_at)
      .limit(TERMINE_NOTICES_LIMIT_PER_DAY)
      .pluck(:id, :user_id)

    each_termine_batch(ids_and_user_ids) do |dossiers|
      send_expiration_notices(dossiers, :termine_close_to_expiration_notice_sent_at)
    end
  end

  def delete_never_touched_brouillons
    Dossier.never_touched_brouillon_expired.in_batches.destroy_all
  end

  def delete_expired_brouillons_and_notify
    user_notifications = group_by_user_email(Dossier.brouillon_expired_after_notice_grace)
      .map { |(email, dossiers)| [email, dossiers.map(&:hash_for_deletion_mail)] }

    Dossier.brouillon_expired_after_notice_grace.in_batches.destroy_all

    user_notifications.each do |(email, dossiers_hash)|
      mail = DossierMailer.notify_brouillon_deletion(
        dossiers_hash,
        email
      )
      send_with_delay(mail)
    end
  end

  def delete_expired_brouillons_without_notice
    Dossier.brouillon_expired_without_notice
      .limit(BROUILLON_WITHOUT_NOTICE_DELETION_LIMIT_PER_DAY)
      .in_batches { |batch| batch.each(&:purge_without_notice) }
  end

  def delete_expired_termine_and_notify
    ids_and_user_ids = Dossier.termine_expired_after_notice_grace
      .order(:termine_close_to_expiration_notice_sent_at)
      .limit(TERMINE_DELETION_LIMIT_PER_DAY)
      .pluck(:id, :user_id)

    each_termine_batch(ids_and_user_ids) do |dossiers|
      delete_expired_and_notify(dossiers, notify_on_closed_procedures_to_user: true)
    end
  end

  def update_notifications_dossiers_termine
    # Ids, not a subquery: it would put the sparse scan back inside the in_batches
    # cursor of create_notifications_for_non_customisable_type.
    close_to_expiration_ids = Dossier.termine_close_to_expiration.without_dossier_expirant_notification
      .order(:expired_at)
      .limit(TERMINE_NOTICES_LIMIT_PER_DAY)
      .pluck(:id)
    expired_ids = Dossier.termine_expired_after_notice_grace
      .order(:termine_close_to_expiration_notice_sent_at)
      .limit(TERMINE_DELETION_LIMIT_PER_DAY)
      .pluck(:id)
    close_to_expiration = Dossier.where(id: close_to_expiration_ids)
    expired = Dossier.where(id: expired_ids)

    DossierNotification.create_notifications_for_non_customisable_type(close_to_expiration, :dossier_expirant)
    DossierNotification.destroy_notifications_by_dossier_and_type(expired, :dossier_expirant)
    DossierNotification.create_notifications_for_non_customisable_type(expired, :dossier_suppression)
  end

  private

  # All the dossiers of one user land in the same batch, hence in the same mail.
  def each_termine_batch(ids_and_user_ids)
    batches = [[]]
    ids_and_user_ids.group_by(&:last).each_value do |user_dossiers|
      batches << [] if batches.last.size >= TERMINE_BATCH_SIZE
      batches.last.concat(user_dossiers.map(&:first))
    end

    batches.each do |ids|
      # The state is checked again at processing time: a dossier sent back to
      # instruction since the selection must be neither flagged nor hidden.
      yield Dossier.where(id: ids).state_termine if ids.any?
    end
  end

  def send_expiration_notices(dossiers_close_to_expiration, close_to_expiration_flag)
    user_notifications = group_by_user_email(dossiers_close_to_expiration)
    tiers_notifications = group_by_tiers_email(dossiers_close_to_expiration)
    administration_notifications = group_by_administration_email(dossiers_close_to_expiration, preference: :instant_email_dossier_expiration)

    # One statement per batch: for a notified termine dossier, expiration_date
    # is the notice date plus the remaining weeks.
    now = Time.zone.now
    dossiers_close_to_expiration.update_all(
      close_to_expiration_flag => now,
      expired_at: now + Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks
    )

    user_notifications.each do |(email, dossiers)|
      mail = DossierMailer.notify_near_deletion_to_user(dossiers, email)
      send_with_delay(mail)
    end
    tiers_notifications.each do |(email, dossiers)|
      mail = DossierMailer.notify_near_deletion_for_tiers(dossiers, email)
      send_with_delay(mail)
    end
    administration_notifications.each do |(email, dossiers)|
      mail = DossierMailer.notify_near_deletion_to_administration(dossiers, email)
      send_with_delay(mail)
    end
  end

  def delete_expired_and_notify(dossiers_to_remove, notify_on_closed_procedures_to_user: false)
    user_notifications = group_by_user_email(dossiers_to_remove, notify_on_closed_procedures_to_user: notify_on_closed_procedures_to_user)
      .map { |(email, dossiers)| [email, dossiers.map(&:id)] }
    tiers_notifications = group_by_tiers_email(dossiers_to_remove, notify_on_closed_procedures_to_user: notify_on_closed_procedures_to_user)
      .map { |(email, dossiers)| [email, dossiers.map(&:id)] }
    administration_notifications = group_by_administration_email(dossiers_to_remove, preference: :instant_email_dossier_expired)
      .map { |(email, dossiers)| [email, dossiers.map(&:id)] }

    hidden_dossier_ids = []

    dossiers_to_remove.find_each do |dossier|
      dossier.hide_and_keep_track!(:automatic, :expired)
      hidden_dossier_ids << dossier.id
    end

    user_notifications.each do |(email, dossier_ids)|
      dossier_ids = dossier_ids.intersection(hidden_dossier_ids)
      if dossier_ids.present?
        mail = DossierMailer.notify_automatic_deletion_to_user(
          Dossier.where(id: dossier_ids).to_a,
          email
        )
        send_with_delay(mail)
      end
    end

    tiers_notifications.each do |(email, dossier_ids)|
      dossier_ids = dossier_ids.intersection(hidden_dossier_ids)
      if dossier_ids.present?
        mail = DossierMailer.notify_automatic_deletion_for_tiers(
          Dossier.where(id: dossier_ids).to_a,
          email
        )
        send_with_delay(mail)
      end
    end

    administration_notifications.each do |(email, dossier_ids)|
      dossier_ids = dossier_ids.intersection(hidden_dossier_ids)
      if dossier_ids.present?
        mail = DossierMailer.notify_automatic_deletion_to_administration(
          Dossier.where(id: dossier_ids).to_a,
          email
        )
        send_with_delay(mail)
      end
    end
  end

  def group_by_user_email(dossiers, notify_on_closed_procedures_to_user: false)
    dossiers
      .visible_by_user
      .with_notifiable_procedure(notify_on_closed: notify_on_closed_procedures_to_user)
      .includes(:user, :procedure)
      .group_by(&:user)
      .map { |(user, dossiers)| [user.email, dossiers] }
  end

  def group_by_tiers_email(dossiers, notify_on_closed_procedures_to_user: false)
    dossiers
      .visible_by_user
      .where(for_tiers: true)
      .with_notifiable_procedure(notify_on_closed: notify_on_closed_procedures_to_user)
      .joins(:individual)
      .merge(Individual.with_email_notification)
      .includes(:user, :procedure, :individual)
      .group_by { |d| d.individual.email }
      .map { |email, dossiers| [email, dossiers] }
  end

  def group_by_administration_email(dossiers, preference:)
    dossiers = dossiers
      .visible_by_administration
      .with_notifiable_procedure(notify_on_closed: true)
      .includes(
        :followers_instructeurs,
        procedure: {
          groupe_instructeurs: { instructeurs: :user },
          administrateurs: :user,
        }
      )

    all_procedure_ids = dossiers.pluck('procedures.id').uniq
    all_instructeur_ids = dossiers.pluck('instructeurs.id').uniq
    instructeur_ids_by_procedure_id_not_requesting_email = InstructeursProcedure
      .where(procedure_id: all_procedure_ids, instructeur_id: all_instructeur_ids, preference => false)
      .pluck(:procedure_id, :instructeur_id)
      .group_by(&:first)
      .transform_values { |v| v.map(&:last) }

    dossiers.each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |dossier, h|
      instructeur_ids_not_requesting_email = instructeur_ids_by_procedure_id_not_requesting_email.fetch(dossier.procedure.id, [])

      dossier.followers_instructeurs.each do |instructeur|
        if instructeur_ids_not_requesting_email.exclude?(instructeur.id)
          h[instructeur.email] << dossier
        end
      end

      admin_emails = dossier.procedure.administrateurs.map(&:email)
      dossier.procedure.groupe_instructeurs.each do |groupe|
        groupe.instructeurs.each do |instructeur|
          if admin_emails.include?(instructeur.email) && instructeur_ids_not_requesting_email.exclude?(instructeur.id)
            h[instructeur.email] << dossier
          end
        end
      end
    end.transform_values(&:to_a)
  end

  def all_user_dossiers_brouillon_close_to_expiration(user)
    user.dossiers
      .brouillon_close_to_expiration
      .without_brouillon_expiration_notice_sent
      .visible_by_user
      .with_notifiable_procedure(notify_on_closed: true)
      .includes(:user, :procedure)
  end
end
