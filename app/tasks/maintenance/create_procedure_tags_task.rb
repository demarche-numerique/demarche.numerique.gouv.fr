# frozen_string_literal: true

# this task is used to create the procedure_tags and backfill the procedures that have the tag in their tags array

module Maintenance
  class CreateProcedureTagsTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern
    include StatementsHelpersConcern
    run_on_first_deploy

    def collection
      [
        "Aap",
        "Accompagnement",
        "Action sociale",
        "Adeli",
        "Affectation",
        "Agrément",
        "Agriculture",
        "agroécologie",
        "Aide aux entreprises",
        "Aide financière",
        "Appel à manifestation d’intérêt",
        "AMI",
        "Animaux",
        "Appel à projets",
        "Association",
        "Auto-école",
        "Autorisation",
        "Autorisation d’exercer",
        "Bilan",
        "Biodiversité",
        "Candidature",
        "Cerfa",
        "Chasse",
        "Cinéma",
        "Cmg",
        "Collectivé territoriale",
        "Collège",
        "Convention",
        "Covid",
        "Culture",
        "Dérogation",
        "Diplôme",
        "Drone",
        "DSDEN",
        "Eau",
        "Ecoles",
        "Education",
        "Elections",
        "Energie",
        "Enseignant",
        "ENT",
        "Environnement",
        "Étrangers",
        "Formation",
        "FPRNM",
        "Funéraire",
        "Handicap",
        "Hygiène",
        "Industrie",
        "innovation",
        "Inscription",
        "Logement",
        "Lycée",
        "Manifestation",
        "Médicament",
        "Micro-crèche",
        "MODELE DS",
        "Numérique",
        "Permis",
        "Pompiers",
        "Préfecture",
        "Professionels de santé",
        "Recrutement",
        "Rh",
        "Santé",
        "Scolaire",
        "SDIS",
        "Sécurité",
        "Sécurité routière",
        "Sécurité sociale",
        "Séjour",
        "Service civique",
        "Subvention",
        "Supérieur",
        "Taxi",
        "Télétravail",
        "Tirs",
        "Transition écologique",
        "Transport",
        "Travail",
        "Université",
        "Urbanisme",
      ]
    end

    def process(tag)
      procedure_tag = ProcedureTag.find_or_create_by(name: tag)

      Procedure.where("? ILIKE ANY(tags)", tag).find_each(batch_size: 500) do |procedure|
        procedure.procedure_tags << procedure_tag unless procedure.procedure_tags.include?(procedure_tag)
      end
    end

    def count
      collection.size
    end
  end
end
