# frozen_string_literal: true

class StatsController < ApplicationController
  before_action :authenticate_super_admin!, only: [:download]

  MEAN_NUMBER_OF_CHAMPS_IN_A_FORM = 24.0

  def index
    stat = Stat.first

    procedures = Procedure.publiees_ou_closes

    @procedures_numbers = procedures_numbers(procedures)

    @dossiers_numbers = dossiers_numbers(
      stat.dossiers_not_brouillon,
      stat.dossiers_depose_avant_30_jours,
      stat.dossiers_deposes_entre_60_et_30_jours
    )

    @dossiers_states_for_pie = {
      "Brouillon" => stat.dossiers_brouillon,
      "En construction" => stat.dossiers_en_construction,
      "En instruction" => stat.dossiers_en_instruction,
      "Terminé" => stat.dossiers_termines,
    }

    @procedures_cumulative = cumulative_month_serie(procedures, :published_at)
    @procedures_in_the_last_4_months = last_four_months_serie(procedures, :published_at)

    @dossiers_cumulative = stat.dossiers_cumulative
    @dossiers_in_the_last_4_months = format_keys_as_months(stat.dossiers_in_the_last_4_months)
  end

  def download
    headers = [
      'ID du dossier',
      'ID de la démarche',
      'Nom de la démarche',
      'ID utilisateur',
      'Etat du fichier',
      'Durée en brouillon',
      'Durée en construction',
      'Durée en instruction',
    ]

    data = Dossier
      .includes(:procedure, :user)
      .in_batches
      .flat_map do |dossiers|
      dossiers
        .pluck(
          "dossiers.id",
          "procedures.id",
          "procedures.libelle",
          "users.id",
          "dossiers.state",
          Arel.sql("dossiers.depose_at - dossiers.created_at"),
          Arel.sql("dossiers.en_instruction_at - dossiers.depose_at"),
          Arel.sql("dossiers.processed_at - dossiers.en_instruction_at")
        )
    end

    respond_to do |format|
      format.csv { send_data(SpreadsheetArchitect.to_csv(headers: headers, data: data), filename: "statistiques.csv") }
    end
  end

  private

  def procedures_numbers(procedures)
    total = procedures.count
    last_30_days_count = procedures.where(published_at: 1.month.ago..Time.zone.now).count
    previous_count = procedures.where(published_at: 2.months.ago..1.month.ago).count
    if previous_count != 0
      evolution = (((last_30_days_count.to_f / previous_count) - 1) * 100).round(0)
    else
      evolution = 0
    end
    formatted_evolution = format("%+d", evolution)

    {
      total: total.to_s,
      last_30_days_count: last_30_days_count.to_s,
      evolution: formatted_evolution,
    }
  end

  def dossiers_numbers(total, last_30_days_count, previous_count)
    if previous_count != 0
      evolution = (((last_30_days_count.to_f / previous_count) - 1) * 100).round(0)
    else
      evolution = 0
    end
    formatted_evolution = format("%+d", evolution)

    {
      total: total.to_s,
      last_30_days_count: last_30_days_count.to_s,
      evolution: formatted_evolution,
    }
  end

  def max_date
    if super_admin_signed_in?
      Time.zone.now
    else
      Time.zone.now.beginning_of_month - 1.second
    end
  end

  def format_keys_as_months(series)
    series.transform_keys do |k|
      date = k.is_a?(Date) ? k : (Date.parse(k) rescue k)
      DateFormatHelper.month_year(date)
    end
  end

  def last_four_months_serie(association, date_attribute)
    series = association
      .group_by_month(date_attribute, last: 4, current: super_admin_signed_in?)
      .count
    format_keys_as_months(series)
  end

  def cumulative_month_serie(association, date_attribute)
    sum = 0
    association
      .group_by_month(date_attribute, current: super_admin_signed_in?)
      .count
      .transform_values { |count| sum += count }
  end
end
