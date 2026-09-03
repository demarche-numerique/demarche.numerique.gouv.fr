# frozen_string_literal: true

class APITokenMailerPreview < ActionMailer::Preview
  def expiration
    APITokenMailer.expiration(api_token)
  end

  def becomes_expirable
    APITokenMailer.becomes_expirable(user, [api_token], Date.new(2027, 8, 31))
  end

  def becomes_expirable_with_several_tokens
    tokens = ['Jeton prod', 'Jeton recette'].map { APIToken.new(administrateur:, name: it) }
    APITokenMailer.becomes_expirable(user, tokens, Date.new(2027, 8, 31))
  end

  private

  def api_token
    APIToken.new(
      administrateur: administrateur,
      expires_at: 1.week.from_now,
      name: 'My API token'
    )
  end

  def administrateur
    Administrateur.new(user:)
  end

  def user
    User.new(email: 'admin@a.com')
  end
end
