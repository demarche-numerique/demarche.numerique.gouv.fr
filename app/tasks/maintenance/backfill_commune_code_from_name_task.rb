# frozen_string_literal: true

module Maintenance
  class BackfillCommuneCodeFromNameTask < MaintenanceTasks::Task
    # corrige structure champs commune pour une démarche donnée. Suite à un bug ?
    # 2024-05-31-01 PR #10469

    attribute :procedure_id, :string
    validates :procedure_id, presence: true

    def collection
      procedure = Procedure.find(procedure_id.strip.to_i)
      ChampData.where(type: "Champs::CommuneChamp").where(dossier_id: procedure.dossiers.not_brouillon)
    end

    def process(champ)
      return if champ.type != "Champs::CommuneChamp"
      return if champ.external_id.present?
      return if champ.value.blank?

      value_json = champ.value_json
      return if value_json.blank?
      return if value_json['code_departement'].blank?

      external_id = APIGeoService.commune_code(value_json['code_departement'], champ.value)

      if external_id.present?
        champ.update(external_id:)
      end
    end
  end
end
