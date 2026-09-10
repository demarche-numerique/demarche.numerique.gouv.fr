# frozen_string_literal: true

module Mutations
  # Webhook fetching and authorization are handled by `loads:` on the webhook
  # argument: schema.object_from_id resolves the typed id and
  # Types::WebhookType.authorized? gates access, surfacing not-found and
  # unauthorized as top-level errors like the rest of the API.
  class WebhookBaseMutation < Mutations::BaseMutation
    FEATURE_DISABLED_ERROR = "Les webhooks ne sont pas activés sur cette démarche."

    private

    def feature_disabled?(procedure)
      !procedure.feature_enabled?(:webhooks_api)
    end
  end
end
