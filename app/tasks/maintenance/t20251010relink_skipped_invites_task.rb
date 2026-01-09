# frozen_string_literal: true

module Maintenance
  class T20251010relinkSkippedInvitesTask < MaintenanceTasks::Task
    # En théorie apres avoir confirmé un compte, on lie les invitations envoyées à une adresse électronique d’un compte utilisateur non existant
    # sauf qu’on a pas fait ça pr les comptes crées via agent connect

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    run_on_first_deploy

    def collection
      Invite.where.missing(:user).in_batches
    end

    def process(element)
      linkable_users_and_invite = User.where(email: element.pluck(:email))
      linkable_users_and_invite.each do |linkable_user_and_invite|
        begin
          linkable_user_and_invite.after_confirmation # calls link_invites!
        rescue => err
          Sentry.capture_exception(err)
        end
      end
    end
  end
end
