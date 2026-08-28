# frozen_string_literal: true

class Ami::SendNotificationJob < ApplicationJob
  include Dry::Monads[:result]

  class ConsentCheckError < StandardError; end

  use_sidekiq_retry(report_after_attempts: 8)

  queue_as :default

  # grant_consent: l'usager vient d'accorder son consentement, inutile de le
  # relire — AMI pourrait ne pas l'avoir encore propagé, et une lecture en 404
  # ferait abandonner l'envoi silencieusement.
  def perform(payload, context = {}, grant_consent: false)
    Sentry.set_tags(context)

    fc_hash = payload[:recipient_fc_hash]
    return if fc_hash.blank?
    return if !grant_consent && !consent_granted?(fc_hash, context)

    Rails.logger.debug { "AMI notification sending for dossier #{context[:dossier]}" }

    result = Ami::Client.new.send_notification(payload)

    case result
    in Success(_)
      Rails.logger.debug { "AMI notification sent successfully for dossier #{context[:dossier]}" }
    in Failure(error)
      Rails.logger.error("AMI notification failed for dossier #{context[:dossier]}: #{error}")
      raise "AMI notification failed for dossier #{context[:dossier]}: #{error}"
    end
  end

  private

  # Ne rien envoyer sans consentement est délibéré : le contenu de la
  # notification ne doit pas parvenir à AMI tant que l'usager n'a pas accepté.
  def consent_granted?(fc_hash, context)
    case Ami::ConsentStatus.call(fc_hash)
    when :granted
      true
    when :not_granted, :unavailable
      Rails.logger.debug { "AMI notification skipped for dossier #{context[:dossier]}: no consent" }
      false
    else
      # AMI n'a pas su répondre : on ne devine pas, on laisse Sidekiq retenter.
      raise ConsentCheckError, "AMI consent check failed for dossier #{context[:dossier]}"
    end
  end
end
