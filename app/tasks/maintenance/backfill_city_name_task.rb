# frozen_string_literal: true

module Maintenance
  class BackfillCityNameTask < MaintenanceTasks::Task
    # corrige des données du champ adresse suite à un bug
    # introduit pendant quelques jours début mars
    # 2024-04-09-02 PR #10290
    attribute :champ_ids, :string
    validates :champ_ids, presence: true

    def collection
      ChampData.where(id: champ_ids.split(',').map(&:strip).map(&:to_i))
    end

    def process(champ)
      return if champ.type != "Champs::AddressChamp"

      data = champ.data

      return if data.blank?
      return if data['city_name'].present?
      return if data['label'].blank?

      response = Typhoeus.get(
        "#{API_ADRESSE_URL}/search",
        params: { q: data['label'], limit: 1 },
        timeout: 3
      )

      return if response.code != 200

      json = JSON.parse(response.body)
      city = json.dig('features', 0, 'properties', 'city')
      return if city.blank?

      data['city_name'] = city

      champ.update(data:)
    end

    def count
      # Optionally, define the number of rows that will be iterated over
      # This is used to track the task's progress
    end
  end
end
