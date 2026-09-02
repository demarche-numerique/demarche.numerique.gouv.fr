# frozen_string_literal: true

class Cron::SendAPIParticulierTokenExpirationNoticeJob < Cron::CronJob
  self.schedule_expression = "every day at 08:15"

  def perform
    procedures_with_token.find_each do |procedure|
      notify(procedure)
    rescue StandardError => e
      Sentry.capture_exception(e, extra: { procedure_id: procedure.id })
    end
  end

  private

  def notify(procedure)
    return if !uses_api_particulier?(procedure)

    token = procedure.api_particulier_token
    # Pas de rappel mensuel perpétuel sur un brouillon abandonné ou une démarche
    # close, qui ne reçoivent plus de dossiers.
    return if !token.notification_due?(procedure.api_particulier_token_expiration_notice_sent_at, remind: procedure.publiee?)

    procedure.administrateurs.includes(:user).find_each do |admin|
      AdministrateurMailer.api_particulier_token_expiration(admin, procedure).deliver_later
    end

    # update_column : une démarche dont le jeton est illisible ne passe plus la
    # validation, et c'est justement celle qu'on vient de notifier.
    procedure.update_column(:api_particulier_token_expiration_notice_sent_at, Time.current)
  end

  # Tous les états : sans quoi une démarche que le jeton empêche justement de
  # publier ne serait jamais signalée.
  def procedures_with_token
    Procedure.kept.where.not(api_particulier_token: nil)
  end

  # La colonne charrie des jetons v1/v2 abandonnés depuis 2021, sur des démarches
  # dont les champs ont depuis été convertis en texte
  # (T20260817ConvertLegacyAPIParticulierChampsToTextTask) : leurs administrateurs
  # n'ont rien à renouveler.
  #
  # Le tri part des rares démarches qui portent un jeton : passer d'abord par les
  # champs ferait balayer types_de_champ, qui n'a pas d'index sur `type_champ`.
  def uses_api_particulier?(procedure)
    revisions = [procedure.published_revision_id, procedure.draft_revision_id].compact

    ProcedureRevisionTypeDeChamp
      .unscope(:eager_load)
      .joins(:type_de_champ)
      .where(revision_id: revisions)
      .exists?(types_de_champ: { type_champ: TypesDeChamp::FranceConnectTypeDeChamp::REGISTRY.keys.map(&:to_s) })
  end
end
