# frozen_string_literal: true

class Stat < ApplicationRecord
  class << self
    def update_stats
      states = sum_hashes(dossiers_states, deleted_dossiers_states)
      stat = Stat.first || Stat.new

      stat.update(
        dossiers_depose_avant_30_jours: states['dossiers_depose_avant_30_jours'],
        dossiers_deposes_entre_60_et_30_jours: states['dossiers_deposes_entre_60_et_30_jours'],
        dossiers_not_brouillon: states['not_brouillon'],
        dossiers_cumulative: cumulative_month_serie([
          [Dossier.state_not_brouillon, :depose_at],
          [DeletedDossier.where.not(state: :brouillon), :depose_at],
        ]),
        dossiers_in_the_last_4_months: last_four_months_serie([
          [Dossier.state_not_brouillon, :depose_at],
          [DeletedDossier.where.not(state: :brouillon), :depose_at],
        ]),
        administrations_partenaires: AdministrateursProcedure.joins(:procedure).merge(Procedure.publiees_ou_closes).select('distinct administrateur_id').count
      )
    end

    private

    def dossiers_states
      sanitize_and_exec(Dossier, <<-EOF
        SELECT
          COUNT(*) FILTER ( WHERE state != 'brouillon' ) AS "not_brouillon",
          COUNT(*) FILTER ( WHERE state != 'brouillon' and depose_at BETWEEN :one_month_ago AND :now ) AS "dossiers_depose_avant_30_jours",
          COUNT(*) FILTER ( WHERE state != 'brouillon' and depose_at BETWEEN :two_months_ago AND :one_month_ago ) AS "dossiers_deposes_entre_60_et_30_jours"
        FROM dossiers
          WHERE revision_id NOT IN (SELECT r.id FROM procedure_revisions r LEFT JOIN procedures p ON r.procedure_id=p.id WHERE p.aasm_state = 'brouillon')
      EOF
      )
    end

    def deleted_dossiers_states
      sanitize_and_exec(DeletedDossier, <<-EOF
        SELECT
          COUNT(*) AS "not_brouillon",
          COUNT(*) FILTER ( WHERE depose_at BETWEEN :one_month_ago AND :now ) AS "dossiers_depose_avant_30_jours",
          COUNT(*) FILTER ( WHERE depose_at BETWEEN :two_months_ago AND :one_month_ago ) AS "dossiers_deposes_entre_60_et_30_jours"
        FROM deleted_dossiers
      EOF
      )
    end

    def last_four_months_serie(associations_with_date_attribute)
      timeseries = associations_with_date_attribute.map do |association, date_attribute|
        association.group_by_month(date_attribute, last: 4, current: false).count
      end

      sum_hashes(*timeseries).sort.to_h
    end

    def cumulative_month_serie(associations_with_date_attribute)
      timeseries = associations_with_date_attribute.map do |association, date_attribute|
        association.group_by_month(date_attribute, current: false).count
      end

      cumulative_serie(sum_hashes(*timeseries))
    end

    def cumulative_serie(sums)
      sum = 0
      sums.keys.sort.index_with { |date| sum += sums[date] }
    end

    def sum_hashes(*hashes)
      {}.merge(*hashes) { |_k, v1, v2| v1 + v2 }
    end

    def max_date
      Time.zone.now.beginning_of_month - 1.second
    end

    def sanitize_and_exec(model, query)
      sanitized_query = ActiveRecord::Base.sanitize_sql([
        query,
        now: Time.zone.now,
        one_month_ago: 1.month.ago,
        two_months_ago: 2.months.ago,
      ])
      model.connection.select_all(sanitized_query).first
    end
  end
end
