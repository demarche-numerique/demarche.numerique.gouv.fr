# frozen_string_literal: true

# Jetons d'API configurés par un administrateur sur une démarche (API Entreprise,
# API Particulier) : des JWT dont on lit l'expiration localement.
#
# `unusable?` coupe les appels, `needs_renewal?` prévient l'administrateur. Le
# second est faux sans jeton du tout : la démarche est « à configurer », pas « à
# renouveler ».
module ExpiringJwtTokenConcern
  extend ActiveSupport::Concern

  SOON_TO_EXPIRE_DELAY = 1.month

  # Un jeton illisible n'a pas d'échéance sur laquelle caler des relances.
  UNUSABLE_REMINDER_DELAY = 1.month

  NOTIFICATION_WINDOWS = [1.day, 1.week, 1.month].freeze

  included do
    include ActiveModel::Validations

    validates :jwt_token, jwt_token: true, allow_blank: true

    attr_reader :jwt_token
  end

  def initialize(jwt_token)
    @jwt_token = jwt_token
  end

  # `JWT.decode` ne contrôle pas le type des claims : un `exp` textuel ferait
  # lever Time.zone.at, dans une page d'administration ou un mail que rien ne
  # rattrape.
  def expires_at
    exp = decoded_token["exp"]

    Time.zone.at(exp) if exp.is_a?(Numeric)
  end

  def expired?
    return true if decoded_token.blank?

    # we have a decoded token but no exp claim, consider it as non-expiring
    return false if expires_at.nil?

    expires_at <= Time.zone.now
  end

  def expires_soon?
    expires_at.present? && !expired? && expires_at <= SOON_TO_EXPIRE_DELAY.from_now
  end

  def unusable?
    jwt_token.blank? || expired?
  end

  def needs_renewal?
    jwt_token.present? && (unusable? || expires_soon?)
  end

  # Avant l'échéance, les relances se resserrent en suivant NOTIFICATION_WINDOWS.
  # Après, rien ne se répare tout seul : on relance à cadence fixe jusqu'au
  # renouvellement, sans quoi la panne s'installerait en silence — et c'est ce
  # silence qui nous autorise à ne plus remonter ses erreurs à Sentry.
  # `remind: false` pour une démarche qui ne reçoit plus de dossiers.
  def notification_due?(last_sent_at, remind: true)
    return false if !needs_renewal?
    return last_sent_at.blank? || just_expired?(last_sent_at) || (remind && last_sent_at <= UNUSABLE_REMINDER_DELAY.ago) if unusable?

    window = matching_window(expires_at)

    last_sent_at.blank? || matching_window(expires_at, reference_time: last_sent_at) != window
  end

  private

  # Le dernier courrier annonçait une échéance à venir : il en faut un autre
  # maintenant qu'elle est passée.
  def just_expired?(last_sent_at)
    expires_at.present? && last_sent_at < expires_at
  end

  def matching_window(expires_at, reference_time: Time.current)
    NOTIFICATION_WINDOWS.find { |window| expires_at <= reference_time + window }
  end

  def decoded_token
    return {} if jwt_token.blank?

    # Un JWT décodable n'a pas forcément un objet pour charge utile. Mémoïsé
    # aussi en échec : une liste de démarches évalue ces prédicats par centaines.
    @decoded_token ||= JWT.decode(jwt_token, nil, false)[0].then { it.is_a?(Hash) ? it : {} }
  rescue JWT::DecodeError => e
    Rails.logger.error e.message
    @decoded_token = {}
  end
end
