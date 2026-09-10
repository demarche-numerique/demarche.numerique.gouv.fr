# frozen_string_literal: true

module Maintenance
  class T20260722unsetForTiersOnDossiersWithoutMandataireIdentityTask < MaintenanceTasks::Task
    # Documentation: le choix de persona « pour un bénéficiaire » était persisté via
    # update_columns dès le clic sur le bouton radio (1e6f9ba05f), sans l'identité du
    # mandataire. Les dossiers déposés dans cet état sont invalides à chaque save
    # (RAILS-M9G / RAILS-M99) : l'instructeur ne peut plus changer leur état. On
    # retire for_tiers de ces dossiers : l'identité saisie (individual) reste celle
    # du dossier, qui redevient « pour soi ».

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    run_on_first_deploy

    def collection
      poisoned = Dossier
        .state_not_brouillon
        .where(for_tiers: true)
        .where("mandataire_first_name IS NULL OR mandataire_first_name = '' OR mandataire_last_name IS NULL OR mandataire_last_name = ''")

      # le timeout local ne couvre pas les requêtes que la gem lance ensuite,
      # et ce pluck doit tenir dans chaque tranche de 5 min du job, qui le rejoue
      ids = with_statement_timeout("4min") { poisoned.pluck(:id) }

      poisoned.where(id: ids)
    end

    def process(dossier)
      dossier.update_columns(for_tiers: false, mandataire_first_name: nil, mandataire_last_name: nil)
    end

    def count
      # la table dossiers est volumineuse et for_tiers n'est pas indexé
    end
  end
end
