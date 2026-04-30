# frozen_string_literal: true

module Maintenance
  class T20260403backfillNoBanAddressValueTask < MaintenanceTasks::Task
    # Documentation: cette tâche permet de rattrapper les value vides pour les
    # champs address no ban avec le 'label' du value_json

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    def collection
      Champs::AddressChamp.all
    end

    def process(champ)
      if champ.value.blank? && !champ.ban? && champ.full_address?
        address_label = champ.value_json&.dig('label')
        champ.update_column(:value, address_label)
      end
    end

    def count
      with_statement_timeout("5min") do
        collection.count(:id)
      end
    end
  end
end
