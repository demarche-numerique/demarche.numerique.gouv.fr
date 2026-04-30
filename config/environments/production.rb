# frozen_string_literal: true

require "active_support/core_ext/integer/time"
require Rails.root.join("app/lib/balancer_delivery_method")

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE").to_sym

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    config.logger = ActiveSupport::Logger.new(STDOUT)
      .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
      .then { |logger| ActiveSupport::TaggedLogging.new(logger) }
  else
    # Use default logging formatter so that PID and timestamp are not suppressed.
    config.log_formatter = ::Logger::Formatter.new
  end

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("DS_LOG_LEVEL", "info")

  # Use a different cache store in production.
  if ENV['REDIS_CACHE_URL'].present?
    redis_options = {
      url: ENV['REDIS_CACHE_URL'],
      connect_timeout: 0.2,
      error_handler: -> (method:, returning:, exception:) {
        Sentry.capture_exception exception, level: 'warning',
          tags: { method: method, returning: returning }
      },
    }

    redis_options[:ssl] = ENV['REDIS_CACHE_SSL'] == 'enabled'

    if ENV['REDIS_CACHE_SSL_VERIFY_NONE'] == 'enabled'
      redis_options[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
    end

    config.cache_store = :redis_cache_store, redis_options
  end

  # Use a real queuing backend for Active Job (and separate queues per environment).
  config.active_job.queue_adapter = ENV.fetch('RAILS_QUEUE_ADAPTER') { :sidekiq }
  # config.active_job.queue_name_prefix = "tps_production"

  # Disable caching for Action Mailer templates even if Action Controller
  # caching is enabled.
  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  if ENV['MAILTRAP_ENABLED'] == 'enabled'
    config.action_mailer.delivery_method = :mailtrap
  elsif ENV['MAILCATCHER_ENABLED'] == 'enabled'
    config.action_mailer.delivery_method = :mailcatcher
  elsif ENV['CLASSIC_SMTP_ENABLED'] == 'enabled'
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              ENV.fetch("SMTP_HOST"),
      port:                 ENV.fetch("SMTP_PORT"),
      domain:               ENV.fetch("SMTP_HOST"),
      user_name:            ENV.fetch("SMTP_USER"),
      password:             ENV.fetch("SMTP_PASS"),
      authentication:       ENV.fetch("SMTP_AUTHENTICATION"),
      enable_starttls_auto: ENV.fetch("SMTP_TLS").present?,
    }
  elsif ENV['SENDMAIL_ENABLED'] == 'enabled'
    config.action_mailer.delivery_method = :sendmail
    config.action_mailer.sendmail_settings = {
      location: ENV.fetch("SENDMAIL_LOCATION"),
      arguments: ENV.fetch("SENDMAIL_ARGUMENTS"),
    }
  else
    brevo_weight = ENV.fetch('BREVO_BALANCING_VALUE') { 0 }.to_i
    scaleway_weight = ENV.fetch('SCALEWAY_BALANCING_VALUE') { 0 }.to_i
    ActionMailer::Base.add_delivery_method :balancer, BalancerDeliveryMethod
    config.action_mailer.balancer_settings = {
      brevo: brevo_weight,
      scaleway: scaleway_weight,
    }
    config.action_mailer.delivery_method = :balancer
  end

  # Configure default root URL for generating URLs to routes
  config.action_mailer.default_url_options = {
    protocol: :https,
    host: ENV['APP_HOST'],
  }
  # Configure default root URL for email assets
  config.action_mailer.asset_host = "https://" + ENV['APP_HOST']

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Log disallowed deprecations.
  config.active_support.disallowed_deprecation = false

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id, :created_at, :updated_at]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # Inserts middleware to perform automatic connection switching.
  # The `database_selector` hash is used to pass options to the DatabaseSelector
  # middleware. The `delay` is used to determine how long to wait after a write
  # to send a subsequent read to the primary.
  #
  # The `database_resolver` class is used by the middleware to determine which
  # database is appropriate to use based on the time delay.
  #
  # The `database_resolver_context` class is used by the middleware to set
  # timestamps for the last write to the primary. The resolver uses the context
  # class timestamps to determine how long to wait before reading from the
  # replica.
  #
  # By default Rails will store a last write timestamp in the session. The
  # DatabaseSelector middleware is designed as such you can define your own
  # strategy for connection switching and pass that into the middleware through
  # these configuration options.
  # config.active_record.database_selector = { delay: 2.seconds }
  # config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  # config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session

  Rails.application.routes.default_url_options = {
    protocol: :https,
    host: ENV['APP_HOST'],
  }

  # The Content-Security-Policy is NOT in Report-Only mode
  config.content_security_policy_report_only = false

  config.lograge.enabled = ENV['LOGRAGE_ENABLED'] == 'enabled'
end
