# frozen_string_literal: true

module Maintenance
  class T20261117harmonizeProcedureTagsTask < MaintenanceTasks::Task
    # Documentation: cette tâche harmonise les ProcedureTag. Chaque tag de MAPPING
    # est remplacé par ses tags cibles, qui doivent exister, sur toutes ses
    # démarches, puis supprimé ; une liste vide le supprime sans remplacement.
    # Les tags de RENAMES sont renommés.

    RENAMES = {
      "Élections" => "Élection",
      "Permis" => "Permis de conduire",
      "Risques majeurs" => "Risques naturels",
    }.freeze

    MAPPING = {
      "Aap" => ["Appel à projets"],
      "Adeli" => ["Santé"],
      "Agroécologie" => ["Agriculture", "Transition écologique"],
      "AMI" => ["Appel à manifestation d'intérêt"],
      "Autorisation d'exercer" => ["Autorisation"],
      "Cerfa" => [],
      "Cinéma" => ["Audiovisuel"],
      "CMG" => ["Aide financière"],
      "Collège" => ["Éducation"],
      "Covid" => ["Santé"],
      "Drone" => [],
      "DSDEN" => ["Éducation"],
      "Écoles" => ["Éducation"],
      "Enseignant" => ["Éducation"],
      "ENT" => ["Éducation"],
      "FPRNM" => ["Transition écologique", "Aide financière"],
      "Hygiène" => ["Santé"],
      "Langue française" => [],
      "Lycée" => ["Éducation"],
      "Médicament" => ["Santé"],
      "Micro-crèche" => ["Petite enfance"],
      "MODELE DS" => [],
      "Professionnels de santé" => ["Santé"],
      "Scolaire" => ["Éducation"],
      "SDIS" => ["Pompiers"],
      "Séjour" => ["Étrangers"],
      "Supérieur" => ["Éducation"],
      "Télétravail" => ["RH"],
      "Université" => ["Éducation"],
      "Victimes de guerre" => ["Histoire"],
    }.freeze

    def collection
      RENAMES.keys + MAPPING.keys
    end

    def process(name)
      tag = ProcedureTag.find_by(name:)
      return if tag.nil?

      return tag.update!(name: RENAMES.fetch(name)) if RENAMES.key?(name)

      targets = MAPPING.fetch(name).map { ProcedureTag.find_by!(name: it) }

      ProcedureTag.transaction do
        Procedure.with_discarded.joins(:procedure_tags).where(procedure_tags: { id: tag }).find_each do |procedure|
          procedure.procedure_tags << (targets - procedure.procedure_tags)
        end
        tag.destroy!
      end
    end
  end
end
