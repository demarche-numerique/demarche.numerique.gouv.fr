# frozen_string_literal: true

class AdministrateurMailerPreview < ActionMailer::Preview
  def activate_before_expiration
    user = User.new(reset_password_sent_at: Time.zone.now)

    AdministrateurMailer.activate_before_expiration(user, "a4d4e4f4b4d445")
  end

  def api_entreprise_token_expiration
    administrateur = Administrateur.first
    procedure = Procedure.kept.where.not(api_entreprise_token: [nil, '']).first || Procedure.first
    AdministrateurMailer.api_entreprise_token_expiration(administrateur, procedure)
  end

  def notify_webhook_auto_disabled
    administrateur = Administrateur.first
    webhook = Webhook.first || Webhook.new(procedure: Procedure.first, url: "https://exemple.fr/webhook", label: "Mon webhook", event_types: ["dossier_depose"])
    webhook.auto_disabled_at ||= Time.zone.now
    webhook.last_error ||= "HTTP 500 (Internal Server Error)"
    AdministrateurMailer.notify_webhook_auto_disabled(administrateur, webhook)
  end

  def api_token_expiration
    user = User.last
    tokens = [APIToken.last, APIToken.last]
    AdministrateurMailer.api_token_expiration(user, tokens)
  end
end
