# frozen_string_literal: true

class APIBretagneService
  include Dry::Monads[:result]
  HOST = 'https://api.databretagne.fr'
  ENDPOINTS = {
    # see: https://api.databretagne.fr/budget/doc#operations-Auth_Controller-post_login
    "login" => "/budget/api/v1/auth/login",
    # see: https://api.databretagne.fr/budget/doc#operations-Centre_couts-get_ref_controller_list
    "centre-couts" => '/budget/api/v1/centre-couts',
    # see: https://api.databretagne.fr/budget/doc#operations-Domaine_Fonctionnel-get_ref_controller_list
    "domaine-fonct" => '/budget/api/v1/domaine-fonct',
    # see: https://api.databretagne.fr/budget/doc#operations-Referentiel_Programmation-get_ref_controller_list
    "ref-programmation" => '/budget/api/v1/ref-programmation',
  }

  def search_domaine_fonct(code_or_label: "")
    request(endpoint: ENDPOINTS.fetch('domaine-fonct'), code_or_label:)
  end

  def search_centre_couts(code_or_label: "")
    request(endpoint: ENDPOINTS.fetch('centre-couts'), code_or_label:)
  end

  def search_ref_programmation(code_or_label: "")
    request(endpoint: ENDPOINTS.fetch('ref-programmation'), code_or_label:)
  end

  private

  def request(endpoint:, code_or_label:)
    return [] if (code_or_label || "").strip.size < 3
    url = build_url(endpoint)
    result = fetch_page(url:, params: { query: code_or_label, page_number: 1 })
    return result if result.is_a?(Dry::Monads::Failure)

    result[:items] || []
  end

  def fetch_page(url:, params:, remaining_retry_count: 1)
    result = call(url:, params:)

    case result
    in Failure(code:, error:) if code.in?(401..403)
      if remaining_retry_count > 0
        login
        fetch_page(url:, params:, remaining_retry_count: 0)
      else
        result
      end
    in Success(body:)
      body
    else # no response gives back a 204, so we don't try to JSON.parse(nil) to avoid error
      { items: [] }
    end
  end

  def call(url:, params:)
    token = authorization_token
    return token if token.is_a?(Dry::Monads::Failure)

    API::Client.new.(url:, params:, authorization_token: token, method:)
  end

  def method
    :get
  end

  def authorization_token
    return @token if @token

    case login
    in Success(token:)
      @token = token
    in Failure => failure
      return failure
    end
  end

  def login
    result = API::Client.new.call(url: build_url(ENDPOINTS.fetch("login")),
                                  json: {
                                    email: ENV['API_DATABRETAGE_USERNAME'],
                                    password: ENV['API_DATABRETAGE_PASSWORD'],
                                  },
                                  method: :post)
    case result
    in Success(body:)
      Success(token: body.split("Bearer ")[1])
    in Failure(code:, error:) if code == 403
      Failure(API::Client::Error[:invalid_credential, code, false, error])
    else
      Failure(API::Client::Error[:api_down])
    end
  end

  def build_url(endpoint)
    uri = URI(HOST)
    uri.path = endpoint
    uri
  end
end
