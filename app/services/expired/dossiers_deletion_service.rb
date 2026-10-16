# frozen_string_literal: true

class Expired::DossiersDeletionService < Expired::MailRateLimiter
  BROUILLON_DELETION_EMAILS_LIMIT_PER_DAY = ENV.fetch("BROUILLON_DELETION_EMAILS_LIMIT_PER_DAY", 10_000).to_i
  BROUILLON_WITHOUT_NOTICE_DELETION_LIMIT_PER_DAY = ENV.fetch("BROUILLON_WITHOUT_NOTICE_DELETION_LIMIT_PER_DAY", 20_000).to_i
  TERMINE_NOTICES_LIMIT_PER_DAY = ENV.fetch("TERMINE_NOTICES_LIMIT_PER_DAY", 50_000).to_i
  TERMINE_DELETION_LIMIT_PER_DAY = ENV.fetch("TERMINE_DELETION_LIMIT_PER_DAY", 50_000).to_i
  # Termine dossiers are flagged or hidden, expired brouillons deleted, then
  # mailed to their users, batch by batch: what a failure mid-run can lose is
  # bounded to one batch (a retry starts over from the scopes, which no longer
  # match the dossiers already processed).
  # A batch grows past this size rather than splitting a user's dossiers.
  BATCH_SIZE = 1000

  def process_never_touched_dossiers_brouillon; delete_never_touched_brouillons; end

  def process_expired_dossiers_brouillon
    send_brouillon_expiration_notices
    delete_expired_brouillons_and_notify
    delete_expired_brouillons_without_notice
  end

  def process_expired_dossiers_termine
    send_termine_expiration_notices
    delete_expired_termine_and_notify
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

    notify_administration_once(:notify_near_deletion_to_administration) do |administration_dossier_ids|
      each_batch_by_user(ids_and_user_ids, Dossier.state_termine) do |dossiers|
        send_expiration_notices(dossiers, :termine_close_to_expiration_notice_sent_at, administration_dossier_ids)
      end
    end
  end

  # Nobody ever filled these brouillons in: they go without any mail.
  def delete_never_touched_brouillons
    Dossier.never_touched_brouillon_expired.in_batches.destroy_all
    Dossier.unclaimed_prefilled_brouillon_expired.in_batches.destroy_all
  end

  def delete_expired_brouillons_and_notify
    ids_and_user_ids = Dossier.brouillon_expired_after_notice_grace.pluck(:id, :user_id)

    each_batch_by_user(ids_and_user_ids, Dossier.brouillon_expired_after_notice_grace) do |dossiers|
      user_notifications = group_by_user_email(dossiers)

      dossiers.each(&:purge_draft)
      deleted_dossier_ids = dossiers.filter(&:destroyed?).map(&:id)

      user_notifications.each do |(email, user_dossiers)|
        deleted_dossiers = user_dossiers.filter { deleted_dossier_ids.include?(it.id) }
        if deleted_dossiers.any?
          mail = DossierMailer.notify_brouillon_deletion(
            deleted_dossiers.map(&:hash_for_deletion_mail),
            email
          )
          send_with_delay(mail)
        end
      end
    end
  end

  def delete_expired_brouillons_without_notice
    Dossier.brouillon_expired_without_notice
      .limit(BROUILLON_WITHOUT_NOTICE_DELETION_LIMIT_PER_DAY)
      .in_batches { |batch| batch.each(&:purge_draft) }
  end

  def delete_expired_termine_and_notify
    ids_and_user_ids = Dossier.termine_expired_after_notice_grace
      .order(:termine_close_to_expiration_notice_sent_at)
      .limit(TERMINE_DELETION_LIMIT_PER_DAY)
      .pluck(:id, :user_id)

    notify_administration_once(:notify_automatic_deletion_to_administration) do |administration_dossier_ids|
      each_batch_by_user(ids_and_user_ids, Dossier.state_termine) do |dossiers|
        delete_expired_and_notify(dossiers, administration_dossier_ids, notify_on_closed_procedures_to_user: true)
      end
    end
  end

  private

  # All the dossiers of one user land in the same batch, hence in the same mail.
  def each_batch_by_user(ids_and_user_ids, scope)
    batches = [[]]
    ids_and_user_ids.group_by(&:last).each_value do |user_dossiers|
      batches << [] if batches.last.size >= BATCH_SIZE
      batches.last.concat(user_dossiers.map(&:first))
    end

    batches.each do |ids|
      # The scope is checked again at processing time: a dossier that left it
      # since the selection, such as a termine dossier sent back to instruction,
      # is skipped.
      yield scope.where(id: ids) if ids.any?
    end
  end

  # An instructeur follows the dossiers of many users, hence of many batches:
  # their mail waits for the end of the run. When a batch fails, it still goes
  # out for the batches processed before, which a retry no longer matches.
  def notify_administration_once(mail_method)
    dossier_ids_by_email = Hash.new { |h, k| h[k] = [] }
    yield dossier_ids_by_email
  ensure
    dossier_ids_by_email.each do |email, dossier_ids|
      send_with_delay(DossierMailer.public_send(mail_method, dossier_ids, email))
    end
  end

  def send_expiration_notices(dossiers_close_to_expiration, close_to_expiration_flag, administration_dossier_ids)
    user_notifications = group_by_user_email(dossiers_close_to_expiration)
    tiers_notifications = group_by_tiers_email(dossiers_close_to_expiration)
    administration_notifications = group_by_administration_email(dossiers_close_to_expiration, preference: :instant_email_dossier_expiration)

    # One statement per batch: for a notified termine dossier, expiration_date
    # is the notice date plus the remaining weeks. The instructeur badge is
    # created in the same transaction, so the flag and the badge always agree.
    now = Time.zone.now
    Dossier.transaction do
      dossiers_close_to_expiration.update_all(
        close_to_expiration_flag => now,
        expired_at: now + Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks
      )
      DossierNotification.create_notifications_for_non_customisable_type(dossiers_close_to_expiration, :dossier_expirant)
    end

    administration_notifications.each do |(email, dossiers)|
      administration_dossier_ids[email].concat(dossiers.map(&:id))
    end

    user_notifications.each do |(email, dossiers)|
      mail = DossierMailer.notify_near_deletion_to_user(dossiers, email)
      send_with_delay(mail)
    end
    tiers_notifications.each do |(email, dossiers)|
      mail = DossierMailer.notify_near_deletion_for_tiers(dossiers, email)
      send_with_delay(mail)
    end
  end

  def delete_expired_and_notify(dossiers_to_remove, administration_dossier_ids, notify_on_closed_procedures_to_user: false)
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

    administration_notifications.each do |(email, dossier_ids)|
      dossier_ids = dossier_ids.intersection(hidden_dossier_ids)
      administration_dossier_ids[email].concat(dossier_ids) if dossier_ids.present?
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
