# frozen_string_literal: true

# This setup is primarily for first deployment, because consequently
# we can add new features from the Web UI. However when the new DB is created
# this will immediately migrate the default features to be controlled.
#
require 'flipper/adapters/active_record'
require 'flipper/adapters/active_support_cache_store'

def setup_features(features, enabled_by_default: [])
  existing = Flipper.preload_all.map { _1.name.to_sym }
  missing = features - existing

  missing.each do |feature|
    # Feature is disabled by default
    Flipper.add(feature.to_s)
    # Enable on creation only: subsequent boots won't override an operator's choice
    Flipper.enable(feature) if enabled_by_default.include?(feature)
  end
end

# A list of features to be deployed on first push
features = [
  :administrateur_web_hook,
  :blocking_pending_correction,
  :dossier_pdf_vide,
  :engagement_juridique_type_de_champ,
  :export_avec_horodatage,
  :export_order_by_revision,
  :groupe_instructeur_api_hack,
  :pro_connect_restricted,
  :quotient_familial_type_de_champ,
  :pre_rempli_type_de_champ,
  :rdv,
  :sva,
  :switch_domain,
  :llm_nightly_improve_procedure,
  :ami_notifications,
  :api_entreprise_tva_job,
  :usager_dossiers_alert_filters,
  :s3_storage,
]

def database_exists?
  # A simple query is required: since Rails 7.2 `connection` is lazy and does
  # not connect until first use, so it never raises here on a missing database.
  ActiveRecord::Base.connection.select_value('SELECT 1')
  true
rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError, PG::ConnectionBad
  false
end

Flipper.configure do |config|
  config.adapter do
    Flipper::Adapters::ActiveSupportCacheStore.new(
      Flipper::Adapters::ActiveRecord.new,
      ActiveSupport::Cache::MemoryStore.new,
      10.seconds
    )
  end
end

ActiveSupport.on_load(:active_record) do
  if database_exists? && ActiveRecord::Base.connection.data_source_exists?('flipper_features')
    setup_features(features, enabled_by_default: [:api_entreprise_tva_job])
  end
end

Rails.application.configure do
  config.flipper.actor_limit = 500 # default is 100 but hide_instructeur_email feature has ~478
  # don't preload features for /assets/* but do for everything else
  config.flipper.preload = -> (request) { !request.path.start_with?('/assets/', '/ping') }
  config.flipper.strict = Rails.env.development?
end

module Flipper
  module Adapters
    class ActiveRecord
      class Gate < Model
        validates :value, format: /\A[A-z]+;\d+\z/, if: -> { key == 'actors' }
      end
    end
  end
end
# Cf https://github.com/flippercloud/flipper/blob/main/lib/flipper/adapters/active_record.rb
