# frozen_string_literal: true

namespace :lint do
  desc 'Run the Ruby linters (rubocop, haml-lint, i18n-tasks and the custom text checks)'
  task :ruby do
    sh "bundle exec rubocop --parallel"
    sh "bundle exec haml-lint app/views/ app/components/"
    sh "bundle exec i18n-tasks missing --locales fr"
    sh "bundle exec i18n-tasks unused"
    sh "bundle exec i18n-tasks check-consistent-interpolations"

    # Invoked in-process rather than shelled out: these are plain file scans,
    # and each `bundle exec rake` boot costs ~4s.
    ['lint:adresse_electronique', 'lint:apostrophe', 'lint:yaml_newline'].each { Rake::Task[it].invoke }
  end

  desc 'Run the JavaScript, TypeScript, CSS and ERB linters'
  task :js do
    # The `lint` script runs them all in parallel, see package.json
    sh "bun lint"
  end

  desc 'Run the Brakeman security scanner'
  task :security do
    sh "bundle exec brakeman --no-pager"
  end
end

desc 'Run all the linters (CI runs lint:ruby, lint:js and lint:security in parallel jobs)'
task lint: ['lint:ruby', 'lint:js', 'lint:security']
