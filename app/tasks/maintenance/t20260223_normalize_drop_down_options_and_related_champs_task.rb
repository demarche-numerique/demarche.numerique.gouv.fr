# frozen_string_literal: true

module Maintenance
  class T20260223NormalizeDropDownOptionsAndRelatedChampsTask < MaintenanceTasks::Task
    attribute :procedure_id, :string
    validates :procedure_id, presence: true

    DROP_DOWN_TYPES = [
      TypesDeChamp::DropDownList,
      TypesDeChamp::MultipleDropDownList,
    ].map(&:name).freeze

    def collection
      procedure = Procedure.find(procedure_id.strip)

      TypeDeChamp
        .joins(:revisions)
        .where(type: DROP_DOWN_TYPES, procedure_revisions: { procedure_id: procedure.id })
        .distinct
    end

    def process(type_de_champ)
      update_drop_down_list_champs(type_de_champ) if type_de_champ.drop_down_list?
      update_multiple_drop_down_list_champs(type_de_champ) if type_de_champ.multiple_drop_down_list?

      normalized_options = normalize_options(type_de_champ.drop_down_options)
      return if normalized_options == type_de_champ.drop_down_options

      type_de_champ.update!(drop_down_options: normalized_options)
    end

    private

    def normalize_options(options)
      Array(options).filter_map { normalize_value(_1) }
    end

    def update_drop_down_list_champs(type_de_champ)
      Champs::DropDownListChamp.where(stable_id: type_de_champ.stable_id).where.not(value: nil).find_each do |champ|
        new_value = normalize_value(champ.value)
        next if champ.value == new_value

        champ.update_columns(value: new_value)
      end
    end

    def update_multiple_drop_down_list_champs(type_de_champ)
      Champs::MultipleDropDownListChamp.where(stable_id: type_de_champ.stable_id).where.not(value: nil).find_each do |champ|
        old_values = parse_json_array(champ.value)
        next if old_values.nil?

        new_values = old_values
          .filter_map { normalize_value(_1) }
          .uniq
        next if new_values == old_values

        champ.update_columns(value: new_values.presence&.to_json)
      end
    end

    def normalize_value(value)
      value.to_s.squish.presence
    end

    def parse_json_array(value)
      parsed = JSON.parse(value)
      parsed if parsed.is_a?(Array)
    rescue JSON::ParserError
      nil
    end
  end
end
