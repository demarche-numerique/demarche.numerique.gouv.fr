# frozen_string_literal: true

class Expired::DossiersDeletionService < Expired::MailRateLimiter
  BROUILLON_DELETION_EMAILS_LIMIT_PER_DAY = ENV.fetch("BROUILLON_DELETION_EMAILS_LIMIT_PER_DAY", 10_000).to_i
  BROUILLON_WITHOUT_NOTICE_DELETION_LIMIT_PER_DAY = ENV.fetch("BROUILLON_WITHOUT_NOTICE_DELETION_LIMIT_PER_DAY", 20_000).to_i
  TERMINE_NOTICES_LIMIT_PER_DAY = ENV.fetch("TERMINE_NOTICES_LIMIT_PER_DAY", 50_000).to_i
  TERMINE_DELETION_LIMIT_PER_DAY = ENV.fetch("TERMINE_DELETION_LIMIT_PER_DAY", 50_000).to_i

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
    selection = brouillons_to_warn
    # Only the dossiers a mail can be sent for count toward the daily limit.
    notifiable = selection
      .with_notifiable_procedure
      .order(:removal_due_at)
      .limit(BROUILLON_DELETION_EMAILS_LIMIT_PER_DAY)

    Removal::Runner.new(scope: selection).each_batch(notifiable) do |batch|
      # One mail per user of the batch, with every brouillon of theirs to
      # warn: those of a closed procedure too, which expire the same night.
      user_ids = batch.with_notifiable_procedure.distinct.pluck(:user_id)
      dossiers = selection
        .where(user_id: user_ids)
        .with_notifiable_procedure(notify_on_closed: true)
        .includes(:user, :procedure)
        .to_a

      # The mail announces expired_at: store it before enqueuing the mail.
      # Only the brouillons actually warned are mailed: one edited or
      # trashed since the selection is left where its own writer put it.
      warned_ids = warn_brouillons(dossiers.map(&:id))

      dossiers.filter { warned_ids.include?(it.id) }.group_by(&:user).each do |user, user_dossiers|
        send_with_delay(DossierMailer.notify_brouillon_near_deletion(user_dossiers, user.email))
      end
    end
  end

  def send_termine_expiration_notices
    # Ids first: the selection is a sparse filter over the 8M termine dossiers,
    # and iterating it with in_batches walked the primary key (#13816).
    selection = Dossier.termine_close_to_expiration.without_termine_expiration_notice_sent
      .order(:expired_at)
      .limit(TERMINE_NOTICES_LIMIT_PER_DAY)

    # The state is checked again at processing time: a dossier sent back to
    # instruction since the selection must be neither flagged nor hidden.
    Removal::Runner.new(scope: Dossier.state_termine).each_batch(selection) do |dossiers|
      send_expiration_notices(dossiers, :termine_close_to_expiration_notice_sent_at)
    end
  end

  def delete_never_touched_brouillons
    Removal::Runner.new(scope: Dossier.never_touched_brouillon_expired).each_batch(&:destroy_all)
  end

  def delete_expired_brouillons_and_notify
    selection = brouillons_warned_over

    Removal::Runner.new(scope: selection).each_batch do |batch|
      # One load per batch: once destroyed, there is nothing left to query.
      dossiers = batch.includes(:user, :procedure).to_a
      dossiers.each(&:destroy)

      dossiers.filter { it.destroyed? && notifiable?(it) }.group_by(&:user).each do |user, user_dossiers|
        send_with_delay(DossierMailer.notify_brouillon_deletion(user_dossiers.map(&:hash_for_deletion_mail), user.email))
      end
    end
  end

  def delete_expired_brouillons_without_notice
    selection = brouillons_expired_without_notice
    # Oldest expiry first, through the index on the stage and its due date:
    # ordering by id walked the primary key of every dossier to find the few
    # expired ones.
    oldest_first = selection
      .order(:removal_due_at)
      .limit(BROUILLON_WITHOUT_NOTICE_DELETION_LIMIT_PER_DAY)

    Removal::Runner.new(scope: selection).each_batch(oldest_first) do |dossiers|
      dossiers.each(&:purge_without_notice)
    end
  end

  def delete_expired_termine_and_notify
    selection = Dossier.termine_expired_after_notice_grace
      .order(:termine_close_to_expiration_notice_sent_at)
      .limit(TERMINE_DELETION_LIMIT_PER_DAY)

    Removal::Runner.new(scope: Dossier.state_termine).each_batch(selection) do |dossiers|
      delete_expired_and_notify(dossiers, notify_on_closed_procedures_to_user: true)
    end
  end

  private

  def send_expiration_notices(dossiers_close_to_expiration, close_to_expiration_flag)
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

  # The brouillons whose notice is due tonight: the retained ones past their
  # notice date, which is their due date.
  def brouillons_to_warn
    Dossier.state_brouillon.where(for_procedure_preview: false).removal_due(:retained)
  end

  # The brouillons destroyed tonight, two weeks after their notice: the
  # warned ones past their due date.
  def brouillons_warned_over
    Dossier.state_brouillon.where(for_procedure_preview: false).removal_due(:warned)
  end

  # The brouillons nobody could be warned about (a preview, a procedure
  # closed or still in brouillon), past their expiration: the retained ones
  # whose notice date is two weeks behind. A warned one was destroyed
  # earlier tonight, with its mail.
  def brouillons_expired_without_notice
    Dossier.state_brouillon
      .removal_due(:retained, Time.zone.now - Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks)
      .joins(:procedure)
      .where("dossiers.for_procedure_preview = TRUE OR procedures.aasm_state IN (?)", %w[close brouillon])
  end

  # with_notifiable_procedure, on a dossier already loaded.
  def notifiable?(dossier) = dossier.user_id.present? && dossier.procedure.notifiable?

  # Only the brouillons still retained are warned at all: one edited or
  # trashed since the selection is left where its own writer put it. Returns
  # the ids warned.
  def warn_brouillons(ids) = Dossier.where(id: ids).warn_removal!(Time.zone.now).to_set
end
