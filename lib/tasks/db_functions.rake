# frozen_string_literal: true

require_relative "../../db/migrate/20260402182757_recreate_search_terms_indexes_with_unaccent"

namespace :db do
  namespace :schema do
    task create_functions: :environment do
      ActiveRecord::Base.connection.execute <<~SQL.squish
        CREATE EXTENSION IF NOT EXISTS unaccent;
        #{RecreateSearchTermsIndexesWithUnaccent::CREATE_FRENCH_UNACCENT_FTS_CONFIG}
      SQL
    end
  end
end

Rake::Task["db:schema:load"].enhance(["db:schema:create_functions"])
Rake::Task["db:test:load_schema"].enhance(["db:schema:create_functions"])
