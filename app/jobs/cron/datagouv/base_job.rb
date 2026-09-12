# frozen_string_literal: true

class Cron::Datagouv::BaseJob < Cron::CronJob
  include DatagouvCronSchedulableConcern

  # Monthly publication to an external API: keep the full retry budget.
  use_sidekiq_retry

  DATASET = '62d677bde7e4ca2c759142ce'
  DATE_FORMAT = "%Y-%m"

  def perform(resource, headers, file_name)
    csv = data_gouv_csv(resource, headers)

    missing_months(csv)
      .map { |month| data_for(month:) }
      .each { |data| csv << data }

    APIDatagouv::API.upload_csv(file_name, csv, DATASET, resource)
  end

  def data_gouv_csv(resource, headers)
    APIDatagouv::API.existing_csv(DATASET, resource) ||
      CSV::Table.new([], headers:)
  end

  def missing_months(csv)
    last_date = Date.strptime(csv[-1]['mois'], DATE_FORMAT).in_time_zone if csv.present?

    start_month = last_date.present? ? last_date + 1.month : previous_month

    Enumerator.produce(start_month) { _1 + 1.month }
      .take_while { _1 <= previous_month }
  end

  private

  def previous_month
    1.month.ago.beginning_of_month
  end
end
