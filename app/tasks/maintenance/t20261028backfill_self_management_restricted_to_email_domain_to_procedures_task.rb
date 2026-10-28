# frozen_string_literal: true

module Maintenance
  class T20261028backfillSelfManagementRestrictedToEmailDomainToProceduresTask < MaintenanceTasks::Task
    # Disable the email domain restriction on self-managed procedures whose instructeurs have different email domains

    include RunnableOnDeployConcern

    run_on_first_deploy

    def collection
      Procedure.with_discarded.where(instructeurs_self_management_enabled: true)
    end

    def process(procedure)
      domains = procedure.instructeurs.includes(:user).map(&:email_domain)

      procedure.update_column(:self_management_restricted_to_email_domain, false) if domains.uniq.many?
    end
  end
end
