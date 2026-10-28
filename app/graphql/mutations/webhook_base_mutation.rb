# frozen_string_literal: true

module Mutations
  # webhookCreer loads no webhook and checks the flag on its démarche.
  class WebhookBaseMutation < Mutations::BaseMutation
    FEATURE_DISABLED_ERROR = "Les webhooks ne sont pas activés sur cette démarche."

    def authorized?(**args)
      webhook = args[:webhook]
      return false, { errors: [FEATURE_DISABLED_ERROR] } if webhook.present? && feature_disabled?(webhook.procedure)

      super
    end

    private

    def feature_disabled?(procedure)
      !procedure.feature_enabled?(:webhooks_api)
    end
  end
end
