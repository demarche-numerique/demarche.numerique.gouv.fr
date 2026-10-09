# frozen_string_literal: true

module Maintenance
  class T20261005ConvertParis2024AccreditationChampsToTextTask < MaintenanceTasks::Task
    # Convertit les champs cojo en texte avant le retrait du type. Le nom de la tâche
    # évite « COJO » pour survivre au retrait de l'inflection.

    LEGACY_TYPE_CHAMP = 'cojo'
    LEGACY_CHAMP_TYPE = 'Champs::COJOChamp'

    def collection
      TypeDeChamp.where(type_champ: LEGACY_TYPE_CHAMP).pluck(:id, :stable_id)
    end

    def process((id, stable_id))
      ChampData
        .where(stable_id:, type: LEGACY_CHAMP_TYPE)
        .find_each do |champ|
          champ.update_columns(
            type: 'Champs::TextChamp',
            value: legacy_value(champ),
            data: nil,
            external_id: nil,
            external_state: nil
          )
        end

      TypeDeChamp.where(id:).update_all(type_champ: TypeDeChamp.type_champs.fetch(:text))
    end

    private

    def legacy_value(champ)
      identifiers = parse_external_id(champ.read_attribute_before_type_cast(:external_id))
      data = champ.data.to_h

      parts = []
      parts << "N° d’accréditation : #{identifiers['accreditation_number']}" if identifiers['accreditation_number'].present?
      parts << "date de naissance : #{format_date(identifiers['accreditation_birthdate'])}" if identifiers['accreditation_birthdate'].present?

      case data['accreditation_success']
      when true
        parts << "nom dans la base d’accréditation : #{data['accreditation_last_name']} #{data['accreditation_first_name']}".strip
      when false
        parts << "accréditation non trouvée"
      end

      parts.join(', ').presence
    end

    def parse_external_id(external_id)
      return {} if external_id.blank?

      JSON.parse(external_id)
    rescue JSON::ParserError
      { 'accreditation_number' => external_id }
    end

    def format_date(value)
      Date.parse(value).strftime('%d/%m/%Y')
    rescue ArgumentError, TypeError
      value
    end
  end
end
