# frozen_string_literal: true

module Maintenance
  class UpdateDraftRevisionTypeDeChampsTask < MaintenanceTasks::Task
    # Modifie le form d’une démarche à partir d’un CSV (dev pour les Fonds Verts)

    csv_collection

    # CSV structure:
    # demarche_id, id,  new_libelle, new_description, new_required, new_position
    # 1234, QnbaF==, Nouveau libellé, Nouvelle description, true, 0
    # 1234, QNbZ0==, Un autre libellé, Encore une desc,, 1
    #
    # Remarques:
    # - Toutes les valeurs sont écrasées sur la draft revision
    # - Les positions doivent être dans l’ordre, sans trou, en suivant l’ordre de l’éditeur du formulair !
    # - Les positions commencent à 0, comme un index
    # - La position de l’ensemble du bloc répétable est celle du "parent"
    # - Les champs des blocs répétables suivent la position du parent (c’est notre code qui la réinitialise à 0)
    # - Ne permet pas de "sortir" des champs de blocs répétables, ni en ajouter (on peut juste réorganiser à l’intérieur du bloc)
    def process(row)
      procedure_id = row["demarche_id"]
      typed_id = row["id"]

      Rails.logger.info { "#{self.class.name}: Processing #{row.inspect}" }

      revision = Procedure.find(procedure_id).draft_revision

      stable_id = revision.types_de_champ.find { _1.to_typed_id == typed_id }&.stable_id

      fail "TypeDeChamp not found ! #{typed_id}" if stable_id.nil?

      tdc = revision.find_and_ensure_exclusive_use(stable_id)
      revision.move_type_de_champ(stable_id, Integer(row['new_position']))

      tdc.update!(
        libelle: row["new_libelle"].strip,
        description: row["new_description"]&.strip.to_s, # we want empty string
        mandatory: row["new_required"] == "true"
      )
    end
  end
end
