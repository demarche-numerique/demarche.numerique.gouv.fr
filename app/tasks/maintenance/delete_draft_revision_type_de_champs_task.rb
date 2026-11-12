# frozen_string_literal: true

module Maintenance
  class DeleteDraftRevisionTypeDeChampsTask < MaintenanceTasks::Task
    # Modifie le form d’une démarche à partir d’un CSV (dev spécifique Fonds Verts).
    # See UpdateDraftRevisionTypeDeChampsTask for more information
    # Just add delete_flag with "true" in CSV to effectively remove the type de champ from the draft.
    csv_collection

    def process(row)
      return unless row["delete_flag"] == "true"

      procedure_id = row["demarche_id"]
      typed_id = row["id"]

      Rails.logger.info { "#{self.class.name}: Processing #{row.inspect}" }

      revision = Procedure.find(procedure_id).draft_revision

      stable_id = revision.type_de_champs.find { _1.to_typed_id == typed_id }&.stable_id

      fail "TypeDeChamp not found ! #{typed_id}" if stable_id.nil?

      type_de_champ = revision.type_de_champ(stable_id)

      if revision.coordinate_for(type_de_champ)&.used_by_routing_rules?
        fail "#{typed_id} / #{type_de_champ.libelle} » est utilisé pour le routage, vous ne pouvez pas le supprimer."
      end

      revision.remove_type_de_champ(stable_id)
    end
  end
end
