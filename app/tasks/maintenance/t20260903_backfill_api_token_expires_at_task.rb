# frozen_string_literal: true

module Maintenance
  class T20260903BackfillAPITokenExpiresAtTask < MaintenanceTasks::Task
    # Documentation: cette tâche donne une date d’expiration aux jetons d’API qui
    # n’en ont pas, et prévient les administrateurs dont les jetons sont encore
    # capables de s’authentifier.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Deliberately manual: it sends thousands of emails and sets a deadline that
    # will break live integrations. It must not fire on a deploy.

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

      # Only version 3 tokens can still authenticate: APIToken.authenticate filters
      # on it. Older ones are inert, so we date them without warning anyone.
      live = eternals.where(version: 3).to_a

      eternals.update_all(expires_at: expires_on)

      return if live.empty?

      user = administrateur.user
      return if user.nil? # historical accounts with no usable user

      APITokenMailer.becomes_expirable(user, live, expires_on).deliver_later
    end
  end
end
