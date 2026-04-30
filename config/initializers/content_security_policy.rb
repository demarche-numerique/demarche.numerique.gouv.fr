# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    images_whitelist = ["*.openstreetmap.org", "*.cloud.ovh.net", "image.crisp.chat", "*"]
    images_whitelist << URI(DS_PROXY_URL).host if DS_PROXY_URL.present?
    images_whitelist << URI(MATOMO_IFRAME_URL).host if MATOMO_IFRAME_URL.present?
    policy.img_src(:self, :data, :blob, *images_whitelist)

    # Javascript: allow us, Brevo and Matomo.
    # We need unsafe_inline because miniprofiler and us have some inline buttons :(
    scripts_whitelist = ["client.crisp.chat", "cdn.jsdelivr.net", "integration.lasuite.numerique.gouv.fr", "unpkg.com"]
    scripts_whitelist << URI(MATOMO_IFRAME_URL).host if MATOMO_IFRAME_URL.present?
    policy.script_src(:self, :unsafe_eval, :unsafe_inline, :blob, *scripts_whitelist)

    # CSS: We have a lot of inline style, and some <style> tags.
    # It's too complicated to be fixed right now (and it wouldn't add value: this is hardcoded in views, so not subject to injections)
    policy.style_src(:self, :unsafe_inline, "client.crisp.chat", "unpkg.com", "cdn.jsdelivr.net")

    connect_whitelist = ["client.crisp.chat", "wss://client.relay.crisp.chat", "storage.crisp.chat", "integration.lasuite.numerique.gouv.fr", "app.franceconnect.gouv.fr", "openmaptiles.data.gouv.fr", "openmaptiles.geo.data.gouv.fr", "openmaptiles.github.io", "tiles.geo.api.gouv.fr", "data.geopf.fr", "object.data.gouv.fr"]
    connect_whitelist << ENV.fetch('APP_HOST')
    connect_whitelist << ENV.fetch('APP_HOST_LEGACY') if ENV.key?('APP_HOST_LEGACY') && ENV['APP_HOST_LEGACY'] != ENV['APP_HOST']
    connect_whitelist << "*.amazonaws.com" if Rails.configuration.active_storage.service == :amazon
    connect_whitelist += ENV.values_at('SENTRY_DSN_JS', 'SENTRY_DSN_RAILS').compact_blank.map { URI(it).host }.uniq
    connect_whitelist << URI(DS_PROXY_URL).host if DS_PROXY_URL.present?
    connect_whitelist << URI(API_ADRESSE_URL).host if API_ADRESSE_URL.present?
    connect_whitelist << URI(API_EDUCATION_URL).host if API_EDUCATION_URL.present?
    connect_whitelist << URI(API_GEO_URL).host if API_GEO_URL.present?
    connect_whitelist << ENV.fetch("MATOMO_HOST") if ENV.enabled?("MATOMO")
    policy.connect_src(:self, *connect_whitelist.compact)

    # Frames: allow some iframes
    frame_whitelist = []
    # allow Matomo's iframe on the /suivi page
    frame_whitelist << URI(MATOMO_IFRAME_URL).host if ENV.enabled?("MATOMO")
    # allow pdf iframes in the PJ gallery
    frame_whitelist << URI(DS_PROXY_URL).host if DS_PROXY_URL.present?
    frame_whitelist << "*.crisp.help" if ENV.enabled?("CRISP")
    policy.frame_src(:self, *frame_whitelist)

    # Everything else: allow us
    # Add the error source in the violation notification
    default_whitelist = ["integration.lasuite.numerique.gouv.fr", "fonts.gstatic.com", "in-automate.sendinblue.com", "player.vimeo.com", "app.franceconnect.gouv.fr", "client.crisp.chat", "image.crisp.chat", "storage.crisp.chat", "*.crisp.help", "*.sibautomation.com", "sibautomation.com", "data"]
    default_whitelist += ENV.values_at('SENTRY_DSN_JS', 'SENTRY_DSN_RAILS').compact_blank.map { URI(it).host }.uniq
    default_whitelist << URI(DS_PROXY_URL).host if DS_PROXY_URL.present?
    policy.default_src(:self, :data, :blob, :report_sample, *default_whitelist)

    if Rails.env.development?
      # Allow LiveReload requests
      policy.connect_src(*policy.connect_src, "ws://localhost:3035", "http://localhost:3035")

      # Allow Vite.js
      policy.connect_src(*policy.connect_src, "ws://#{ViteRuby.config.host_with_port}")
      policy.script_src(*policy.script_src, :unsafe_eval, "http://#{ViteRuby.config.host_with_port}")

    elsif Rails.env.test?
      # Disallow all connections to external domains during tests
      policy.img_src(:self, :data, :blob)
      policy.script_src(:self, :unsafe_eval, :unsafe_inline, :blob)
      policy.style_src(:self, :unsafe_inline)
      policy.connect_src(:self)
      policy.frame_src(:self)
      policy.default_src(:self, :data, :blob)
    end
  end

  #  Generate session nonces for permitted importmap, inline scripts, and inline styles.
  #  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  #  config.content_security_policy_nonce_directives = %w(script-src style-src)
  #
  #  Report violations without enforcing the policy.
  #  config.content_security_policy_report_only = true
end
