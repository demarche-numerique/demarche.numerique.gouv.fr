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

  def api_particulier_token_expiration
    administrateur = Administrateur.first
    procedure = Procedure.kept.where.not(api_particulier_token: nil).first || Procedure.first
    AdministrateurMailer.api_particulier_token_expiration(administrateur, procedure)
  end

  def api_token_expiration
    user = User.last
    tokens = [APIToken.last, APIToken.last]
    AdministrateurMailer.api_token_expiration(user, tokens)
  end
end
