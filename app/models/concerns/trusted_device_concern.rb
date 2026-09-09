# frozen_string_literal: true

module TrustedDeviceConcern
  extend ActiveSupport::Concern

  TRUSTED_DEVICE_COOKIE_NAME = :trusted_device
  TRUSTED_DEVICE_PERIOD = 1.month

  def trust_device(start_at, instructeur, trusted_device_token = nil)
    cookies.encrypted[TRUSTED_DEVICE_COOKIE_NAME] = {
      value: JSON.generate({ created_at: start_at, instructeur_id: instructeur.id }),
      expires: start_at + TRUSTED_DEVICE_PERIOD,
      httponly: true,
      secure: Rails.env.production?,
    }
    if trusted_device_token
      trusted_device_token.update(activated_at: start_at)
    end
  end

  # The cookie only vouches for the instructeur it was issued to: a browser trusted
  # for one account must still go through the email link for any other account.
  def trusted_device?
    payload = trusted_device_cookie_payload

    return false if payload.nil? || current_instructeur.nil?

    created_at = Time.zone.parse(payload['created_at'].to_s)

    return false if created_at.blank? || created_at <= TRUSTED_DEVICE_PERIOD.ago

    if payload['instructeur_id'].present?
      payload['instructeur_id'] == current_instructeur.id
    else
      adopt_legacy_trusted_device_cookie(created_at)
    end
  end

  def trusted_device_renewal_notice(trusted_device_token)
    period = ((trusted_device_token.created_at + TRUSTED_DEVICE_PERIOD) - Time.zone.now).to_i / ActiveSupport::Duration::SECONDS_PER_DAY

    "Votre connexion sécurisée a bien été renouvelée. Votre navigateur est authentifié pour #{period} jours."
  end

  def send_login_token_or_bufferize(instructeur)
    if !instructeur.young_login_token?
      token = instructeur.create_trusted_device_token
      InstructeurMailer.send_login_token(instructeur, token, Current.host).deliver_later
      true
    else
      false
    end
  end

  private

  # Cookies issued before the instructeur id was stored carry no owner, but the token
  # activated when the cookie was written does: trust_device stamps activated_at with the
  # very timestamp it puts in the cookie. So a legacy cookie is adopted only for the
  # instructeur we can prove it was issued to — another instructeur signing in from the
  # same browser finds no token of its own and still goes through the email link.
  #
  # Rewriting the cookie with its original created_at leaves the expiry untouched: no
  # browser gains a fresh period, and the last legacy cookie dies one TRUSTED_DEVICE_PERIOD
  # after this ships. The branch can be deleted then.
  def adopt_legacy_trusted_device_cookie(created_at)
    # The cookie only keeps whole seconds (JSON.generate serializes the time through to_s)
    # while activated_at keeps microseconds.
    return false if !current_instructeur.trusted_device_tokens
      .exists?(activated_at: created_at...(created_at + 1.second))

    # No token passed on purpose: activated_at is already set, and stamping it again would
    # move the token inside TrustedDeviceToken.expiring_in_one_week and delay the renewal
    # email sent by Cron::TrustedDeviceTokenRenewalJob.
    trust_device(created_at, current_instructeur)

    true
  end

  def trusted_device_cookie_payload
    cookie = cookies.encrypted[TRUSTED_DEVICE_COOKIE_NAME]

    return if cookie.blank?

    JSON.parse(cookie)
  rescue JSON::ParserError
    nil
  end
end
