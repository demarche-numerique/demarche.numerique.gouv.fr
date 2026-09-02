# frozen_string_literal: true

class Cron::SendAPIEntrepriseTokenExpirationNoticeJob < Cron::CronJob
  self.schedule_expression = "every day at 08:00"

  def perform
    procedures_with_specific_token.find_each do |procedure|
      # Une démarche au jeton biscornu ne doit pas priver les suivantes de leur
      # notification.
      notify(procedure)
    rescue StandardError => e
      Sentry.capture_exception(e, extra: { procedure_id: procedure.id })
    end
  end

  private

  def notify(procedure)
    token = procedure.api_entreprise_token
    # Une démarche qui ne reçoit plus de dossiers est signalée une fois : sans
    # cela, un jeton illisible — désormais couvert par needs_renewal? — vaudrait
    # un rappel mensuel perpétuel sur un brouillon abandonné ou une démarche close.
    return if !token.notification_due?(procedure.api_entreprise_token_expiration_notice_sent_at, remind: procedure.publiee?)

    procedure.administrateurs.includes(:user).find_each do |admin|
      AdministrateurMailer.api_entreprise_token_expiration(admin, procedure).deliver_later
    end

    # update_column : une démarche dont le jeton est illisible ne passe plus la
    # validation, et c'est justement celle qu'on vient de notifier.
    procedure.update_column(:api_entreprise_token_expiration_notice_sent_at, Time.current)
  end

  # Tous les états, comme avant : un administrateur qui prépare une démarche doit
  # être prévenu que son jeton expire avant de la publier.
  def procedures_with_specific_token
    Procedure.kept.where.not(api_entreprise_token: [nil, ''])
  end
end
