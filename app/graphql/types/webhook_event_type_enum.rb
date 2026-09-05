# frozen_string_literal: true

class Types::WebhookEventTypeEnum < Types::BaseEnum
  Webhook::EVENT_TYPES.each do |event_type|
    value event_type, value: event_type
  end

  description "Types d’évènements auxquels un webhook peut être abonné"
end
