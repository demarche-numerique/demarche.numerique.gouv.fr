# frozen_string_literal: true

module Ami
  class Client
    include Dry::Monads[:result]

    EVENT_PATH = "/api/v2/event"

    # Lecture et écriture partagent le même chemin, le hash France Connect
    # identifiant l'usager côté AMI.
    CONSENT_PATH = "/api/v1/consent"
    CONSENT_READ_TIMEOUT = 3
    CONSENT_WRITE_TIMEOUT = 5

    # Le contrat accepte aussi consent: false, qui révoque. On ne l'expose pas :
    # la révocation se fait depuis l'application mobile.
    CONSENT_GRANTED_PAYLOAD = { consent: true }.freeze

    # PUT et non POST : l'événement est identifié par le partenaire et l'objet
    # associé, donc un rejeu ne crée pas de doublon (200 s'il existait, 201 sinon).
    def send_notification(payload)
      handle_result(call_api(url: build_url(EVENT_PATH), json: payload, method: :put))
    end

    # Succès si l'usager a consenti au suivi de ses démarches, échec en 404 sinon.
    def consent(fc_hash)
      handle_bodyless_result(
        call_api(url: consent_url(fc_hash), method: :get, timeout: CONSENT_READ_TIMEOUT)
      )
    end

    # Transmet un consentement. Il n'existe volontairement pas de méthode de
    # révocation : celle-ci se fait uniquement depuis l'application mobile.
    def grant_consent(fc_hash)
      handle_bodyless_result(
        call_api(
          url: consent_url(fc_hash),
          json: CONSENT_GRANTED_PAYLOAD,
          method: :post,
          timeout: CONSENT_WRITE_TIMEOUT
        )
      )
    end

    def configured?
      api_url.present? && api_user.present? && api_password.present?
    end

    private

    def call_api(**options)
      result = API::Client.new.call(userpwd: credentials, **options)
      log_api_call(options, result)
      result
    end

    # Les échanges avec AMI sont invisibles depuis l'application : en
    # développement, on trace une ligne par appel, suivable avec un simple
    # `tail -f log/development.log | grep '\[AMI\]'`. Volontairement limitée à
    # l'URL, la méthode et le code : ni payload ni réponse, donc aucune donnée
    # métier dans les logs.
    def log_api_call(options, result)
      return if !Rails.env.development?

      verb = options.fetch(:method, :get).to_s.upcase
      Rails.logger.info("[AMI] #{verb} #{options.fetch(:url).path} → #{response_code_for(result)}")
    end

    # Une trace de confort ne doit jamais casser l'appel qu'elle observe : on ne
    # suppose pas la forme du résultat.
    def response_code_for(result)
      case result
      in Success(API::Client::OK => ok) then ok.response.code
      in Failure(API::Client::Error => error) then error.code
      else "?"
      end
    end

    def api_url = ENV.fetch("AMI_API_URL", nil)
    def api_user = ENV.fetch("AMI_API_USER", nil)
    def api_password = ENV.fetch("AMI_API_PASSWORD", nil)
    def credentials = "#{api_user}:#{api_password}"

    def consent_url(fc_hash) = build_url("#{CONSENT_PATH}/#{fc_hash}")

    def build_url(path)
      uri = URI(api_url)
      uri.path = path
      uri
    end

    def handle_result(result)
      case result
      in Success(body:)
        Success(body)
      in Failure(API::Client::Error => error)
        Failure(error)
      end
    end

    # Les endpoints de consentement répondent sans corps : API::Client échoue
    # alors à parser le JSON et renvoie un échec, bien que l'appel ait réussi.
    def handle_bodyless_result(result)
      case handle_result(result)
      in Failure(API::Client::Error => error) if error.type == :json && error.code.in?(200..299)
        Success(nil)
      in other
        other
      end
    end
  end
end
