# frozen_string_literal: true

module Maintenance
  class T20260828RemoveAmiRecipientFcHashV2FeatureTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    OBSOLETE_FEATURES = [
      :ami_recipient_fc_hash_v2,
    ].freeze

    def collection
      OBSOLETE_FEATURES
    end

    def process(feature_key)
      Flipper.remove(feature_key)
    end
  end
end
