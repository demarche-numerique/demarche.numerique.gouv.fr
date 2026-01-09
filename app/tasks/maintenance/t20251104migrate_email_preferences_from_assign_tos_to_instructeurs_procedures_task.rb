# frozen_string_literal: true

module Maintenance
  class T20251104migrateEmailPreferencesFromAssignTosToInstructeursProceduresTask < MaintenanceTasks::Task
    # Documentation: cette tâche permet d’injecter dans la table instructeurs_procedures
    # les préférences email des instructeurs depuis la table assign_tos.
    # On s’intéresse ici uniquement aux emails dont la valeur par défaut est false,
    # c’est à dire tous sauf le récapitualtif hebdo car on vient dans cette PR#
    # volontairement passer à false la valeur en base.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    COLUMNS_TO_MIGRATE = {
      daily_email_notifications_enabled: :daily_email_summary,
      instant_email_dossier_notifications_enabled: :instant_email_new_dossier,
      instant_email_message_notifications_enabled: :instant_email_new_message,
      instant_expert_avis_email_notifications_enabled: :instant_email_new_expert_avis,
    }.freeze

    def collection
      ids = AssignTo
        .where(daily_email_notifications_enabled: true)
        .or(AssignTo.where(instant_email_dossier_notifications_enabled: true))
        .or(AssignTo.where(instant_email_message_notifications_enabled: true))
        .or(AssignTo.where(instant_expert_avis_email_notifications_enabled: true))
        .joins(:procedure)
        .group("assign_tos.instructeur_id", "procedures.id")
        .select("MIN(assign_tos.id) AS uniq_id")
        .map(&:uniq_id)

      AssignTo
        .includes(:procedure, instructeur: :instructeurs_procedures)
        .find(ids)
    end

    def process(assign_to)
      instructeur = assign_to.instructeur
      procedure = assign_to.procedure

      ip = InstructeursProcedure.find_or_initialize_by(
        instructeur:,
        procedure:
      )

      if ip.new_record?
        ip.last_revision_seen_id = procedure.published_revision_id
        ip.position = instructeur.instructeurs_procedures.maximum(:position).to_i + 1
      end

      COLUMNS_TO_MIGRATE.each do |old_col, new_col|
        ip.public_send("#{new_col}=", true) if assign_to.public_send(old_col)
      end

      ip.save!
    end

    def count
      with_statement_timeout("5min") do
        collection.count
      end
    end
  end
end
