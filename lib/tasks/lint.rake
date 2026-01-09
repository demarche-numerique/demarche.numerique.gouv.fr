# frozen_string_literal: true

task :lint do
  sh "bundle exec rubocop --parallel"
  sh "bundle exec haml-lint app/views/ app/components/"
  sh "bun lint:herb"
  # sh "bun check-format:herb" # TODO: wait for herb formatter v 0.8
  sh "bundle exec i18n-tasks missing --locales fr"
  sh "bundle exec i18n-tasks unused --locale en" # TODO: check for all locales
  sh "bundle exec i18n-tasks check-consistent-interpolations"
  sh "bundle exec brakeman --no-pager"
  sh "bun lint:js"
  sh "bun lint:types"
  sh "bun lint:css"
  sh "bundle exec rake lint:adresse_electronique"
  sh "bundle exec rake lint:french_apostrophe"
end
