# frozen_string_literal: true

class Instructeurs::CellComponent < ApplicationComponent
  include DossierHelper

  def initialize(dossier:, column:, champ_data:)
    @dossier = dossier
    @column = column
    @champ_data = champ_data
  end

  def call
    advanced_layout || simple_layout
  end

  private

  def advanced_layout
    if @column.email?
      email_and_tiers(@dossier)
    elsif @column.dossier_labels?
      tags_label(@dossier.labels)
    elsif @column.avis?
      sum_up_avis(@dossier.avis)
    end
  end

  def simple_layout
    raw_value = raw_value_for_column(@dossier, @column, @champ_data)
    return '' if raw_value.nil?

    format(raw_value)
  end

  def raw_value_for_column(dossier, column, champ_data)
    data = if column.champ_column?
      champ_data[column.stable_id]
    else
      dossier
    end

    column.value(data)
  end

  def format(raw_value)
    ColumnValueFormatter.format(column: @column, raw_value:)
  end

  def email_and_tiers(dossier)
    email = dossier&.user&.email || dossier.user_email_for(:display)

    if dossier.for_tiers
      prenom, nom = dossier&.individual&.prenom, dossier&.individual&.nom
      # I18n.t: this method runs before render, where the component `t` is unavailable
      safe_join([email, I18n.t('views.instructeurs.dossiers.acts_on_behalf'), prenom, nom], ' ') # rubocop:disable DS/GlobalI18nTranslate
    else
      html_escape(email)
    end
  end

  def sum_up_avis(avis)
    result = avis.map(&:question_answer)&.compact&.tally
      &.map { |k, v| I18n.t("helpers.label.question_answer_with_count.#{k}", count: v) } # rubocop:disable DS/GlobalI18nTranslate

    result ? safe_join(result, ' / ') : nil
  end
end
