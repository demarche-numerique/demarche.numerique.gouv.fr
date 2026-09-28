# frozen_string_literal: true

class Brevo::APIDeliveryMethod
  include Dry::Monads[:result]

  class Error < StandardError
    def initialize(error)
      super("Brevo API #{error.kind} (#{error.type}): HTTP #{error.http_code} #{error.brevo_code} #{error.message}")
    end
  end

  class OutageError < Error
    include SentryFingerprint::ProviderOutage

    def initialize(error)
      @provider = 'brevo'
      super
    end
  end

  class ThrottledError < Error; end
  class AccountError < Error; end
  class RejectedError < Error; end

  EXCEPTIONS = {
    outage: OutageError,
    throttled: ThrottledError,
    account: AccountError,
    rejected: RejectedError,
  }.freeze

  attr_reader :settings

  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    mail.ready_to_send!

    case Brevo::API.new.send_email(Brevo::EmailPayload.new(mail).to_h)
    in Success(*message_ids)
      mail.message_id = message_ids.first
    in Failure(kind: :duplicate)
      nil
    in Failure(error)
      raise EXCEPTIONS.fetch(error.kind), error
    end
  end
end
