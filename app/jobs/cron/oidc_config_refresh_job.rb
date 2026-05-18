# frozen_string_literal: true

class Cron::OidcConfigRefreshJob < Cron::CronJob
  self.schedule_expression = "every day at 11:00"

  def perform
    FranceConnectConfig.refresh! if FranceConnectService.enabled?
    ProConnectConfig.refresh!    if ProConnectService.enabled?
  end
end
