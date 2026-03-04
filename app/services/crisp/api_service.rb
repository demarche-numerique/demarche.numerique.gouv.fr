# frozen_string_literal: true

module Crisp
  class APIService
    include Dry::Monads[:result]

    HOST = 'https://api.crisp.chat'
    ENDPOINTS = {
      # https://docs.crisp.chat/references/rest-api/v1/#update-people-data
      "people_data" => '/v1/website/%{website_id}/people/data/%{email}',
      # https://docs.crisp.chat/references/rest-api/v1/#create-a-new-conversation
      "create_conversation" => '/v1/website/%{website_id}/conversation',
      # https://docs.crisp.chat/references/rest-api/v1/#send-a-message-in-conversation
      "send_message" => '/v1/website/%{website_id}/conversation/%{session_id}/message',
      # https://docs.crisp.chat/references/rest-api/v1/#get-a-conversation
      "get_conversation" => '/v1/website/%{website_id}/conversation/%{session_id}',
      # https://docs.crisp.chat/references/rest-api/v1/#get-conversation-metas
      "get_conversation_meta" => '/v1/website/%{website_id}/conversation/%{session_id}/meta',
      # https://docs.crisp.chat/references/rest-api/v1/#update-conversation-metas
      "update_conversation_meta" => '/v1/website/%{website_id}/conversation/%{session_id}/meta',
      # https://docs.crisp.chat/references/rest-api/v1/#list-people-profiles
      "list_people_profiles" => '/v1/website/%{website_id}/people/profiles/%{page_number}',
      # https://docs.crisp.chat/references/rest-api/v1/#remove-profile-data
      "delete_person" => '/v1/website/%{website_id}/people/profile/%{people_id}',
    }.freeze

    def update_people_data(email:, body:)
      endpoint = format(ENDPOINTS['people_data'], website_id:, email: URI.encode_uri_component(email))
      url = build_url(endpoint)

      result = call(url:, json: body, method: :patch)
      handle_result(result)
    end

    def create_conversation
      endpoint = format(ENDPOINTS['create_conversation'], website_id:)
      url = build_url(endpoint)

      result = call(url:, json: {}, method: :post)
      handle_result(result)
    end

    def send_message(session_id:, body:)
      endpoint = format(ENDPOINTS['send_message'], website_id:, session_id:)
      url = build_url(endpoint)

      result = call(url:, json: body, method: :post)
      handle_result(result)
    end

    def get_conversation_meta(session_id:)
      endpoint = format(ENDPOINTS['get_conversation_meta'], website_id:, session_id:)
      url = build_url(endpoint)

      result = call(url:, method: :get)
      handle_result(result)
    end

    def update_conversation_meta(session_id:, body:)
      endpoint = format(ENDPOINTS['update_conversation_meta'], website_id:, session_id:)
      url = build_url(endpoint)

      result = call(url:, json: body, method: :patch)
      handle_result(result)
    end

    def get_conversation(session_id:)
      endpoint = format(ENDPOINTS['get_conversation'], website_id:, session_id:)
      url = build_url(endpoint)

      result = call(url:, method: :get)
      handle_result(result)
    end

    def list_people_profiles(page_number, params)
      endpoint = format(ENDPOINTS['list_people_profiles'], website_id:, page_number:)
      url = build_url(endpoint)

      result = call(url:, params:, method: :get)
      handle_result(result)
    end

    def delete_person(people_id:)
      endpoint = format(ENDPOINTS['delete_person'], website_id:, people_id:)
      url = build_url(endpoint)

      result = call(url:, method: :delete)
      handle_result(result)
    end

    private

    def website_id = ENV.fetch("CRISP_WEBSITE_ID")
    def client_identifier = ENV.fetch("CRISP_CLIENT_IDENTIFIER")
    def client_key = ENV.fetch("CRISP_CLIENT_KEY")

    def call(url:, json: nil, params: nil, method: :get)
      API::Client.new.call(
        url:,
        json:,
        params:,
        method:,
        headers:,
        userpwd: "#{client_identifier}:#{client_key}"
      )
    end

    def headers
      {
        'X-Crisp-Tier' => 'plugin',
      }
    end

    def build_url(endpoint)
      uri = URI(HOST)
      uri.path = endpoint
      uri
    end

    def handle_result(result)
      case result
      in Success(body:)
        Success(body)
      in Failure(code:, error:)
        Failure(API::Client::Error[:api_error, code, false, error])
      end
    end
  end
end
