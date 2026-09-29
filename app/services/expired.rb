# frozen_string_literal: true

module Expired
  # User is considered inactive after INACTIVE_USER_RETENTION_IN_YEAR years of idleness regarding
  #   when he does not have a dossier en instruction
  #   or when his last sign in (or account creation, if he never signed in) is older than INACTIVE_USER_RETENTION_IN_YEAR years
  INACTIVE_USER_RETENTION_IN_YEAR = 2

  # Dossier are automatically destroyed after a period (it's configured per Procedure)
  #   a Dossier.en_instruction? is never destroyed
  #   otherwise, a dossier is considered for expiracy after its last traitement
  DEFAULT_DOSSIER_RENTENTION_IN_MONTH = ENV.fetch('NEW_MAX_DUREE_CONSERVATION') { 12 }.to_i

  # Administateur can ask for higher dossier rentention
  #   but we double check if it's a valid usage
  MAX_DOSSIER_RENTENTION_IN_MONTH = 60

  # User are always reminded two weeks prior expiracy (for their account as well as their dossier)
  REMAINING_WEEKS_BEFORE_EXPIRATION = 2

  # A dossier is considered expired after 3 months max of inactivity
  MONTHS_BEFORE_BROUILLON_EXPIRATION = 3

  # A prefilled brouillon nobody claimed (no user) is deleted after this idleness
  DAYS_BEFORE_UNCLAIMED_PREFILLED_EXPIRATION = 5

  # A brouillon never touched since its creation is deleted after this delay
  WEEKS_BEFORE_NEVER_TOUCHED_BROUILLON_EXPIRATION = 2

  # Expiracy jobs are run daily.
  #   it send a lot o email, so we spread our jobs through the day
  def self.schedule_at(caller)
    case caller.name
    when 'Cron::NeverTouchedDossiersBrouillonDeletionJob'
      "every day at 5 am"
    when 'Cron::ExpiredPrefilledDossiersDeletionJob'
      "every day at 3 am"
    when 'Cron::ExpiredDossiersTermineDeletionJob'
      "every day at 1 am"
    when 'Cron::ExpiredDossiersBrouillonDeletionJob'
      "every day at 10 pm"
    when 'Cron::ExpiredUsersDeletionJob'
      "every day at 11 pm"
    when 'Cron::EnableProcedureExpiresWhenTermineEnabledJob'
      "every day at 2 am"
    else
      raise 'please, check the schedule to avoid too much email at the same time'
    end
  end
end
