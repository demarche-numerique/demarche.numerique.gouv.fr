# frozen_string_literal: true

module Maintenance
  class T20250825backfillChampExternalStateTask < MaintenanceTasks::Task
    # Cette tâche convertit les champs COJO / RNF / Référentiel au niveau système
    # de machine à état en remplissant la colonne external_state à partir de l’état calculé
    # via les méthodes external_data_fetched? et external_error_present?

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    run_on_first_deploy

    def collection
      # all types with uses_external_data? = true && should_ui_auto_refresh? = true
      targets = [
        "Champs::COJOChamp",
        "Champs::RNFChamp",
        "Champs::ReferentielChamp",
      ]

      # there are too many pjs to check them all,
      # instead we gonna a use a dedicated tasks working from procedure_id
      # pj_type = "Champs::PieceJustificativeChamp"

      # other with uses_external_data? = true but should_ui_auto_refresh? = false
      # "Champs::AnnuaireEducationChamp",
      # "Champs::CNAFChamp",
      # "Champs::DGFIPChamp",
      # "Champs::MESRIChamp",
      # "Champs::PoleEmploiChamp",

      Champ.where(type: targets)
    end

    def process(champ)
      # ! the old method external_data_fetched? is now removed
      # run the task before applying this version
      #
      # return if !champ.idle?
      # begin
      #   if champ.external_data_fetched?
      #     champ.external_data_fetched!
      #   elsif champ.external_error_present?
      #     champ.external_data_error!
      #   end
      # rescue => e
      #   return if e.message.include?('not found in Revision')
      #   raise e
      # end
    end
  end
end
