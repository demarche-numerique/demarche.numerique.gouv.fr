# frozen_string_literal: true

# Sentry `before_send` hook grouping infrastructure outages by exception class.
#
# Sentry groups events by stacktrace and transaction, so a single Redis,
# PostgreSQL or object storage outage fans out into dozens of issues (one per
# controller action or job, times one per message variant: "Connection
# refused", "Connection timed out", "No route to host"…). Nothing in those
# issues is actionable in the code: they only need to be spotted, then closed
# once the outage is over. Forcing the fingerprint to the exception class makes
# every burst land in a single issue per class, which Sentry reopens as
# "regressed" the next time the component goes down.
#
# Only connection-level errors of our own infrastructure are grouped. Errors
# from external providers (API Entreprise, FranceConnect, mail delivery…) keep
# the default grouping: their failures are per endpoint and per transaction.
module SentryFingerprint
  INFRASTRUCTURE_ERRORS = [
    # Redis (Kredis, cache, Sidekiq)
    Redis::BaseConnectionError,
    RedisClient::ConnectionError,
    # PostgreSQL
    ActiveRecord::ConnectionNotEstablished,
    ActiveRecord::ConnectionFailed,
    PG::ConnectionBad,
    PG::UnableToSend,
    # Object storage (fog-openstack)
    Excon::Error::Socket,
    Excon::Error::Timeout,
    Excon::Error::Server,
  ].freeze

  # Raised while Redis restarts and is not serving reads yet; redis-client
  # maps READONLY and MASTERDOWN to connection errors but not LOADING.
  REDIS_LOADING_PREFIX = "LOADING"

  def self.call(event, hint)
    fingerprint = for_exception(hint[:exception])
    event.fingerprint = fingerprint if fingerprint
    event
  end

  def self.for_exception(exception)
    return if exception.nil?

    infrastructure_error = Sentry::Utils::ExceptionCauseChain
      .exception_to_array(exception)
      .find { infrastructure_error?(it) }

    [infrastructure_error.class.name] if infrastructure_error
  end

  def self.infrastructure_error?(exception)
    case exception
    when Redis::CommandError, RedisClient::CommandError
      exception.message.start_with?(REDIS_LOADING_PREFIX)
    when *INFRASTRUCTURE_ERRORS
      true
    else
      false
    end
  end
  private_class_method :infrastructure_error?
end
