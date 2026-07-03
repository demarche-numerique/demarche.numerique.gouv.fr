# frozen_string_literal: true

module Maintenance
  class RemoveNonUniqueChampsTask < MaintenanceTasks::Task
    attribute :stable_ids, :string
    validates :stable_ids, presence: true

    def collection
      champs = ChampData.where(stable_id: stable_ids.split(',').map(&:strip).map(&:to_i))
      champs
        .group_by { [_1.dossier_id, _1.stream, _1.stable_id, _1.row_id] }
        .values
        .filter { _1.size > 1 }
    end

    def process(champs)
      champs_to_remove = champs.sort_by(&:updated_at)[0...-1]
      champs_to_remove.each do |champ|
        champ.update_column(:stream, 'bad_data')
      end
    end
  end
end
