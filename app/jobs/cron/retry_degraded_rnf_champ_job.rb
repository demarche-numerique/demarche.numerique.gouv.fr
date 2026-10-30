# frozen_string_literal: true

class Cron::RetryDegradedRNFChampJob < Cron::RetryDegradedExternalDataJob
  self.schedule_expression = "every 2 hours at minute 40"
  self.champ_class = Champs::RNFChamp

  private

  # The RNF API publishes no health check: the replay itself is the probe.
  def provider_ready? = ENV['RNF_TOKEN'].present?

  # One token for the whole instance, none per procedure.
  def replayable_procedures = Procedure.all
end
