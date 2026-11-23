# frozen_string_literal: true

module Maintenance
  class T20261113CreateEaeIntegrationProcedureTask < MaintenanceTasks::Task
    # Creates the draft procedure of the administrative integration at the
    # École de l'air et de l'espace (see ProcedureTemplates::EaeIntegration)
    # for the administrateur whose e-mail is given.
    # deadline is the last day an application can be submitted (optional):
    # the procedure closes by itself that night.
    # The procedure is left as a draft: the administrateur checks it, sets its
    # service and zone, adds reviewers to each of its two teams (the platform
    # only checks that one of them has a reviewer) and publishes it.
    # Each run creates a new procedure.

    attribute :administrateur_email, :string
    attribute :lien_dpo, :string
    attribute :deadline, :date
    validates :administrateur_email, presence: true

    def collection
      [Administrateur.joins(:user).find_by!(users: { email: administrateur_email.strip.downcase })]
    end

    def process(administrateur)
      ProcedureTemplates::EaeIntegration.create!(administrateur:, lien_dpo: lien_dpo.presence, deadline:)
    end
  end
end
