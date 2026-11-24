# frozen_string_literal: true

require_relative "../../db/migrate/20260402182757_recreate_search_terms_indexes_with_unaccent"
require_relative "../../db/migrate/20261104160100_add_champs_new_id_mirror_trigger"

namespace :db do
  namespace :schema do
    # In development, db:schema:load also loads the schema into the test
    # database, so the text search configuration must be created in every
    # database of every targeted environment, not just the primary connection.
    task create_functions: :environment do
      env_names = [Rails.env]
      env_names << "test" if Rails.env.development?

      env_names.each do |env_name|
        ActiveRecord::Base.configurations.configs_for(env_name:).each do |db_config|
          ActiveRecord::Base.establish_connection(db_config)
          connection = ActiveRecord::Base.connection
          next if connection.select_value("SELECT 1 FROM pg_ts_config WHERE cfgname = 'french_unaccent'")

          connection.execute <<~SQL.squish
            CREATE EXTENSION IF NOT EXISTS unaccent;
            #{RecreateSearchTermsIndexesWithUnaccent::CREATE_FRENCH_UNACCENT_FTS_CONFIG}
          SQL
        end
      end
    ensure
      ActiveRecord::Base.establish_connection(Rails.env.to_sym)
    end

    # schema.rb cannot represent a trigger, so a database built by db:schema:load
    # has the champs table but not the trigger that mirrors champs.id into
    # champs.new_id. Unlike the text search configuration above, this one needs
    # the table to already exist, so it runs *after* the load rather than as a
    # prerequisite.
    task create_triggers: :environment do
      env_names = [Rails.env]
      env_names << "test" if Rails.env.development?

      env_names.each do |env_name|
        ActiveRecord::Base.configurations.configs_for(env_name:).each do |db_config|
          ActiveRecord::Base.establish_connection(db_config)
          connection = ActiveRecord::Base.connection
          next unless connection.table_exists?(:champs)

          connection.execute(AddChampsNewIdMirrorTrigger::CREATE_CHAMPS_NEW_ID_MIRROR_TRIGGER)
        end
      end
    ensure
      ActiveRecord::Base.establish_connection(Rails.env.to_sym)
    end
  end
end

Rake::Task["db:schema:load"].enhance(["db:schema:create_functions"]) { Rake::Task["db:schema:create_triggers"].invoke }
Rake::Task["db:test:load_schema"].enhance(["db:schema:create_functions"]) { Rake::Task["db:schema:create_triggers"].invoke }
