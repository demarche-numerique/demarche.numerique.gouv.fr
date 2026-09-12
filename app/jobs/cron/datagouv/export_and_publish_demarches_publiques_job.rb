# frozen_string_literal: true

class Cron::Datagouv::ExportAndPublishDemarchesPubliquesJob < Cron::CronJob
  include DatagouvCronSchedulableConcern

  # Monthly publication to an external API: keep the full retry budget.
  use_sidekiq_retry

  self.schedule_expression = "every day at 4:10"
  DATASET = '62a0afdacffa4c3ea5cbd1b4'
  RESOURCE = '666211e9-6226-4fad-8d2f-5a4135f40e47'

  def perform(*args)
    gzip_filepath = [
      'tmp/',
      Time.zone.now.to_fs(:number),
      '-demarches.json.gz',
    ].join

    begin
      DemarchesPubliquesExportService.new(gzip_filepath).call
      io = File.new(gzip_filepath, 'r')
      APIDatagouv::API.upload(io, DATASET, RESOURCE)
    ensure
      FileUtils.rm(gzip_filepath)
    end
  end
end
