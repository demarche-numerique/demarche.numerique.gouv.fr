# frozen_string_literal: true

module Maintenance
  class T20260903BackfillAPITokenExpiresAtTask < MaintenanceTasks::Task
    # Documentation: cette tâche donne une date d’expiration aux jetons d’API qui
    # n’en ont pas, et prévient les administrateurs dont les jetons sont encore
    # capables de s’authentifier.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Deliberately manual: it sets a deadline that will break live integrations.
    # It must not fire on a deploy.

    # Spread the announcements rather than handing them all to the provider at
    # once. Three hours is ample for the volume this covers, and the dating
    # itself does not wait: update_all is cheap and the run should finish
    # quickly.
    SPREAD_DURATION = 3.hours

    # A year from the run rather than a date frozen here: the task is launched by
    # hand, possibly weeks after this merges, and a hardcoded date would silently
    # shorten the notice. Memoized so a single run gives every token the same
    # date even if it takes a while.
    #
    # Reusing the model's cap rather than a bare 1.year keeps an inherited token
    # from outliving one created today — update_all skips validations, so nothing
    # else would catch it.
    def expires_on
      @expires_on ||= APIToken.max_expires_at
    end

    def collection
      Administrateur.where(id: APIToken.where(expires_at: nil).select(:administrateur_id))
    end

    def process(administrateur)
      eternals = administrateur.api_tokens.where(expires_at: nil)

      # Older tokens are inert, so we date them without warning anyone.
      live = eternals.authenticable.to_a

      eternals.update_all(expires_at: expires_on)

      return if live.empty?

      APITokenMailer.becomes_expirable(administrateur.user, live, expires_on)
        .deliver_later(wait: rand(0..SPREAD_DURATION))
    end
  end
end
