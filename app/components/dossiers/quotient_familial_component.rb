# frozen_string_literal: true

class Dossiers::QuotientFamilialComponent < ApplicationComponent
  delegate :fc_data_correct?, :fc_data_incorrect?, to: :@champ

  attr_reader :champ, :profile

  def initialize(champ:, profile:)
    @champ = champ
    @profile = profile
  end

  def call
    safe_join([
      notice,
      champ_content,
    ])
  end

  private

  def notice
    if profile == 'instructeur'
      render Dsfr::NoticeComponent.new(
        closable: false,
        data_attributes: { "data-notice-name" => "info-recuperation-donnees-qf" }
      ) do |c|
        c.with_desc do
          description
        end
      end
    end
  end

  def description
    if fc_data_correct?
      t(".correct_qf_data")
    elsif fc_data_incorrect?
      t(".incorrect_qf_data")
    else
      t(".qf_data_not_fetched")
    end
  end

  def champ_content
    if fc_data_correct?
      render QuotientFamilial::QuotientFamilialComponent.new(qf_data: champ.value_json, with_header: false)
    else
      render partial: "shared/champs/piece_justificative/show", locals: { champ:, profile: }
    end
  end
end
