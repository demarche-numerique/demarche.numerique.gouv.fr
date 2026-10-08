# frozen_string_literal: true

module Tchap
  class APIService
    include Dry::Monads[:result]

    PROVIDER = "Tchap"

    # The homeserver refused the event (bad token, bot not in room…): retrying won't help.
    class RejectedError < StandardError; end

    # https://spec.matrix.org/latest/client-server-api/#put_matrixclientv3roomsroomidsendeventtypetxnid
    # txn_id lets the homeserver drop a retry of an event it already received (for a limited time).
    def send_notice(room_id:, txn_id:, body:, formatted_body:)
      url = "#{TCHAP_HOMESERVER_URL}/_matrix/client/v3/rooms/#{URI.encode_uri_component(room_id)}/send/m.room.message/#{URI.encode_uri_component(txn_id)}"
      json = {
        msgtype: "m.notice",
        body:,
        format: "org.matrix.custom.html",
        formatted_body:,
        # explicit empty mentions: an "@room" typed by a user pings nobody
        "m.mentions": {},
      }

      case API::Client.new.call(url:, json:, method: :put, authorization_token: ENV.fetch("TCHAP_BOT_BUGS_TOKEN"))
      in Success(_)
        nil
      in Failure(code:, error:) if code.between?(400, 499) && code != 429
        raise RejectedError, error.message
      in Failure(error:)
        raise RetryableFetchError.new(error, provider: PROVIDER)
      end
    end
  end
end
