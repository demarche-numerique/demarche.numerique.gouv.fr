# frozen_string_literal: true

class RecreateSearchTermsIndexesWithUnaccent < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  CREATE_FRENCH_UNACCENT_FTS_CONFIG = <<~SQL.squish
    DROP TEXT SEARCH CONFIGURATION IF EXISTS public.french_unaccent;
    CREATE TEXT SEARCH CONFIGURATION public.french_unaccent ( COPY = pg_catalog.french );
    ALTER TEXT SEARCH CONFIGURATION public.french_unaccent
      ALTER MAPPING FOR hword, hword_part, word
      WITH unaccent, french_stem;
  SQL

  def up
    safety_assured { execute(CREATE_FRENCH_UNACCENT_FTS_CONFIG) }

    remove_index :dossiers, name: :index_dossiers_on_search_terms, if_exists: true
    remove_index :dossiers, name: :index_dossiers_on_search_terms_private_search_terms, if_exists: true

    add_index :dossiers, "to_tsvector('french_unaccent', search_terms)",
      name: :index_dossiers_on_search_terms,
      using: :gin,
      algorithm: :concurrently

    add_index :dossiers, "to_tsvector('french_unaccent', search_terms || ' ' || private_search_terms)",
      name: :index_dossiers_on_search_terms_private_search_terms,
      using: :gin,
      algorithm: :concurrently
  end

  def down
    remove_index :dossiers, name: :index_dossiers_on_search_terms, if_exists: true
    remove_index :dossiers, name: :index_dossiers_on_search_terms_private_search_terms, if_exists: true

    add_index :dossiers, "to_tsvector('french'::regconfig, search_terms)",
      name: :index_dossiers_on_search_terms,
      using: :gin,
      algorithm: :concurrently

    add_index :dossiers, "to_tsvector('french'::regconfig, (search_terms || private_search_terms))",
      name: :index_dossiers_on_search_terms_private_search_terms,
      using: :gin,
      algorithm: :concurrently

    safety_assured do
      execute "DROP TEXT SEARCH CONFIGURATION IF EXISTS public.french_unaccent;"
    end
  end
end
