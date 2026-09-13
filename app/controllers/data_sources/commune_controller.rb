# frozen_string_literal: true

class DataSources::CommuneController < DataSources::BaseController
  def search
    if params[:q].present? && params[:q].length > 1
      response = APIGeoService.commune_by_name_or_postal_code(params[:q])

      if response.success?
        results = JSON.parse(response.body, symbolize_names: true)

        render json: APIGeoService.format_commune_response(results, params[:with_combined_code])
      elsif response.timed_out?
        return head :gateway_timeout
      else
        if response.code == 0
          error_message = response.return_message
        else
          Sentry.set_extras(body: response.body, code: response.code)
          error_message = "HTTP #{response.code}"
        end

        Sentry.capture_message("Commune API failure", extra: { code: response.code, message: error_message })
        return head :bad_gateway
      end
    else
      render json: []
    end
  end
end
