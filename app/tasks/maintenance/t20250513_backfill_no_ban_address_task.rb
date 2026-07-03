# frozen_string_literal: true

module Maintenance
  class T20250513BackfillNoBanAddressTask < MaintenanceTasks::Task
    # Documentation: marque les anciennes adresses qui n’avaient pas
    # été validées comme étant étant hors BAN
    # Cf https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/10037

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    def collection
      ChampData.where(type: "Champs::AddressChamp")
    end

    def process(champ_data)
      champ = Champ.from_data(champ_data)
      return if champ.nil?

      if champ.legacy_not_ban?
        value_json = {
          not_in_ban: 'true',
          street_address: champ.value,
          label: champ.value,
        }
        champ.update_column(:value_json, value_json)
      end
    end

    def count
      with_statement_timeout("5min") do
        collection.count(:id)
      end
    end
  end
end
