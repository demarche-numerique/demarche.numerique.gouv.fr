# frozen_string_literal: true

class DataSources::AdresseController < DataSources::BaseController
  def search
    query = clean_query(params[:q])

    if query.present?
      response = fetch_results(query)

      if response.success?
        results = JSON.parse(response.body, symbolize_names: true)

        return render json: APIGeoService.format_address_response(results)
      elsif response.timed_out?
        return head :gateway_timeout
      else
        if response.code == 0
          error_message = response.return_message
        else
          Sentry.set_extras(body: response.body, code: response.code)
          error_message = JSON.parse(response.body, symbolize_names: true).dig(:message)
        end

        Sentry.capture_message("Adresse API failure: #{error_message}")
        return head :bad_gateway
      end
    end

    render json: []

  rescue JSON::ParserError => e
    Sentry.set_extras(body: response.body, code: response.code)
    Sentry.capture_exception(e)
    return head :server_error
  end

  private

  def clean_query(query)
    APIGeoService.clean_address_query(query)
  end

  def fetch_results(query)
    Typhoeus.get("#{API_ADRESSE_URL}/search", params: { q: query, limit: 10 }, timeout: 3)
  end
end
