# frozen_string_literal: true

source 'https://gem.coop'

gem 'rails', '~> 7.2.3' # allows update to security fixes at any time

gem 'aasm'
gem 'active_model_serializers'
gem 'activestorage-openstack'
gem 'active_storage_validations'
gem 'addressable'
gem 'administrate'
gem 'administrate-field-enum' # Allow using Field::Enum in administrate
gem 'after_commit_everywhere'
gem 'ancestry'
gem 'anchored'
gem 'bcrypt'
gem 'bootsnap', '>= 1.4.4', require: false # Reduces boot times through caching; required in config/boot.rb
gem 'browser'
gem 'charlock_holmes'
gem 'chartkick'
gem 'clamav-client', require: 'clamav/client'
gem "concurrent-ruby", "< 1.3.5" # force version to avoid https://github.com/rails/rails/pull/54264, should be removed after rails 7.2.x
gem 'connection_pool', '< 3' # connection_pool 3.0 changed initialize signature, incompatible with activesupport 7.2 RedisCacheStore
gem 'daemons'
gem 'deep_cloneable' # Enable deep clone of active record models
gem 'delayed_cron_job', require: false # Cron jobs
gem 'delayed_job_active_record'
gem 'delayed_job_web'
gem 'devise'
gem 'devise-i18n'
gem 'devise-two-factor'
gem 'discard'
gem 'dotenv-rails', require: 'dotenv/load' # dotenv should always be loaded before rails
gem 'dry-monads'
gem 'faraday-jwt'
gem 'flipper'
gem 'flipper-active_record'
gem 'flipper-active_support_cache_store'
gem 'flipper-ui'
gem 'front_matter_parser'
gem 'fugit'
gem 'geocoder'
gem 'geo_coord', require: "geo/coord"
gem 'gitlab-sidekiq-fetcher', require: 'sidekiq-reliable-fetch', git: 'https://github.com/demarche-numerique/reliable-fetch.git'
gem 'gon'
gem 'graphql'
gem 'graphql-batch'
gem 'groupdate'
gem 'haml-rails'
gem 'hashie'
gem 'http_accept_language'
gem 'i18n_data'
gem 'i18n-tasks', require: false
gem 'iban-tools'
gem 'image_processing'
gem 'invisible_captcha'
gem 'jsonpath'
gem 'json_schemer'
gem 'jwt'
gem 'kaminari'
gem 'kredis'
gem 'langchainrb'
gem 'listen' # Required by ActiveSupport::EventedFileUpdateChecker
gem 'lograge'
gem 'logstash-event'
gem 'maintenance_tasks'
gem 'matrix' # needed by prawn and not default in ruby 3.1
gem 'net-imap', require: false # See https://github.com/mikel/mail/pull/1439
gem 'net-pop', require: false # same
gem 'net-smtp', require: false # same
gem 'oauth2'
gem 'omniauth'
gem "omniauth-rails_csrf_protection"
gem "omniauth-rdv-service-public", git: "https://github.com/betagouv/rdv-service-public.git", branch: "production", glob: "lib/omniauth-rdv-service-public/omniauth-rdv-service-public.gemspec"
gem 'openid_connect'
gem 'parsby'
gem 'pg'
gem 'phonelib'
gem 'prawn', '2.4.0' # remove after: https://github.com/prawnpdf/prawn/issues/1346
gem 'prawn-rails' # PDF Generation
gem 'premailer-rails'
gem 'puma' # Use Puma as the app server
gem 'pundit'
gem 'rack-attack'
gem 'rails-i18n' # Locales par défaut
gem 'rails-pg-extras'
gem 'rake-progressbar', require: false
gem 'reactionview'
gem 'redcarpet'
gem 'redis'
gem 'rexml' # add missing gem due to ruby3 (https://github.com/Shopify/bootsnap/issues/325)
gem 'rqrcode'
gem 'ruby-openai'
gem 'sassc-rails' # Use SCSS for stylesheets
gem 'sentry-delayed_job'
gem 'sentry-rails'
gem 'sentry-ruby'
gem 'sentry-sidekiq'
gem 'sib-api-v3-sdk'
gem 'sidekiq', '< 7.3' # 7.3 needs to migrate to sidekiq-cron 2.0
gem 'sidekiq-cron', '< 2.0' # wait for a release without "keys command"
gem 'siret_validator'
gem 'skylight'
gem 'smarter_csv'
gem 'spreadsheet_architect'
gem 'string-similarity'
gem 'strong_migrations' # lint database migrations
gem 'sys-proctable'
gem 'ttfunk', '~> 1.7.0'
gem 'turbo-rails'
gem 'typhoeus'
gem 'ulid-ruby', require: 'ulid'
gem 'vernier'
gem 'view_component'
gem 'vite_rails'
gem 'warden'
gem 'webrick', require: false
gem 'yabeda-prometheus'
gem 'yabeda-sidekiq'
gem 'zipline'
gem 'zxcvbn'

group :test do
  gem 'axe-core-rspec' # accessibility rspec matchers
  gem 'capybara' # Integration testing
  gem 'capybara-email' # Access emails during integration tests
  gem 'capybara-playwright-driver'
  gem 'capybara-screenshot' # Save a dump of the page when an integration test fails
  gem 'factory_bot'
  gem 'launchy'
  gem 'rack_session_access'
  gem 'rails-controller-testing'
  gem 'rspec_junit_formatter'
  gem 'rspec-retry'
  gem 'selenium-devtools'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', require: false
  gem 'simplecov', require: false
  gem 'simplecov-cobertura', require: false
  gem "test-prof"
  gem 'vcr'
  gem 'webmock'
end

group :development do
  gem 'benchmark-ips', require: false
  gem 'brakeman', require: false
  gem 'haml-lint'
  gem 'letter_opener_web'
  gem 'memory_profiler'
  gem 'rack-mini-profiler'
  gem 'rails-erd', require: false # generates `doc/database_models.pdf`
  gem 'rubocop', require: false
  gem 'rubocop-capybara', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'spring' # Spring speeds up development by keeping your application running in the background
  gem 'spring-commands-rspec'
  gem 'stackprof'
  gem 'web-console'
end

group :development, :test do
  gem 'drb' # strange dep required by rspec, should try to be removed after rails 7.2.x
  gem 'graphql-schema_comparator'
  gem 'irb'
  gem 'mina', require: false # Deploy
  gem 'rspec-rails'
  gem 'simple_xlsx_reader'
end
