# frozen_string_literal: true

module Maintenance
  class T20260817ConvertLegacyAPIParticulierChampsToTextTask < MaintenanceTasks::Task
    # Les types de champ API Particulier v1 (cnaf, dgfip, mesri, pole_emploi) ont été
    # retirés du code mais leurs lignes existent toujours en base : `type_champ`
    # n'est plus dans l'enum (lu comme nil) et les champs portent des classes STI
    # supprimées (voir ChampData::REMOVED_TYPES).
    #
    # On les convertit en champ texte. Les identifiants saisis par l'usager
    # (numéro d'allocataire, code postal, numéro fiscal…) étaient stockés dans
    # `external_id` (JSON) ou, pour les plus anciens, dans `value_json` : ils sont
    # recopiés en clair dans `value`. Les données récupérées auprès de l'API
    # restent dans `data`.
    #
    # Ces types n'ayant plus de classe, le backfill de la colonne STI `type`
    # les a laissés à NULL : c'est leur signature. On travaille sur les ids car
    # ces lignes ne peuvent pas être instanciées.

    def collection
      TypeDeChamp.where(type: nil).pluck(:id, :stable_id)
    end

    def process((id, stable_id))
      ChampData
        .where(stable_id:, type: ChampData::REMOVED_TYPES)
        .find_each do |champ|
          champ.update_columns(
            type: 'Champs::TextChamp',
            value: legacy_value(champ),
            value_json: nil,
            external_id: nil,
            external_state: nil
          )
        end

      TypeDeChamp.where(id:).update_all(type: TypesDeChamp::Text.name)
    end

    private

    def legacy_value(champ)
      identifiers = champ.value_json.to_h.merge(parse_external_id(champ.external_id))

      identifiers.compact_blank.map { |key, value| "#{key.humanize} : #{value}" }.join(', ').presence
    end

    def parse_external_id(external_id)
      return {} if external_id.blank?

      JSON.parse(external_id)
    rescue JSON::ParserError
      { 'identifiant' => external_id }
    end
  end
end
