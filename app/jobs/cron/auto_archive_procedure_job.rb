# frozen_string_literal: true

class Cron::AutoArchiveProcedureJob < Cron::CronJob
  self.schedule_expression = "every 1 minute"
  queue_as :critical

  def perform(*args)
    procedures_to_close.each do |procedure|
      # A buggy procedure should NEVER prevent the closing of another procedure
      # we therefore exceptionally add a `begin resue` block.
      begin
        procedure.close!
        AutoArchiveProcedureDossiersJob.perform_later(procedure)
      rescue StandardError => e
        Sentry.capture_exception(e, tags: { procedure: procedure.id })
      end
    end
  end

  def procedures_to_close
    Procedure
      .publiees
      .where(auto_archive_on: ..Time.zone.today)
  end
end
