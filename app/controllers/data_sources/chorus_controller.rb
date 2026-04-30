# frozen_string_literal: true

class DataSources::ChorusController < ApplicationController
  before_action :authenticate_administrateur!

  def search_domaine_fonct
    result = APIBretagneService.new.search_domaine_fonct(code_or_label: params[:q])
    render json: format_or_error(result:,
                                 label_formatter: ChorusConfiguration.method(:format_domaine_fonctionnel_label))
  end

  def search_centre_couts
    result = APIBretagneService.new.search_centre_couts(code_or_label: params[:q])
    render json: format_or_error(result:,
                                 label_formatter: ChorusConfiguration.method(:format_centre_de_cout_label))
  end

  def search_ref_programmation
    result = APIBretagneService.new.search_ref_programmation(code_or_label: params[:q])
    render json: format_or_error(result:,
                                 label_formatter: ChorusConfiguration.method(:format_ref_programmation_label))
  end

  private

  def format_or_error(result:, label_formatter:)
    if result.is_a?(Dry::Monads::Failure)
      Sentry.capture_message("APIBretagneService error", extra: { code: result.failure.code, error: result.failure.error.to_s })
      return []
    end

    result.map do |item|
      {
        label: label_formatter.call(item),
        value: item[:code],
        data: item,
      }
    end
  end
end
