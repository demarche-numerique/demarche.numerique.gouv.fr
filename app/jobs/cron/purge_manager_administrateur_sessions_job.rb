# frozen_string_literal: true

class Cron::PurgeManagerAdministrateurSessionsJob < Cron::CronJob
  self.schedule_expression = "every day at 02:45"

  def perform
    manager_links = AdministrateursProcedure.where(manager: true)

    manager_links.pluck(:procedure_id, :administrateur_id).each do |procedure_id, administrateur_id|
      APIToken.forget_procedure(procedure_id, administrateur: administrateur_id)
    end

    # TODO: add id column to administrateurs_procedures and use destroy_all
    manager_links.delete_all
    AssignTo.where(manager: true).destroy_all
  end
end
