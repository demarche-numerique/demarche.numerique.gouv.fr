# frozen_string_literal: true

Rails.configuration.to_prepare do
  Rails.configuration.event_store = RailsEventStore::JSONClient.new(
    # the default also records the remote ip: events hold nothing personal
    request_metadata: -> (env) { { request_id: ActionDispatch::Request.new(env).uuid } }
  )

  Rails.configuration.event_store.subscribe_to_all_events(Events::LinkToProcedureStream.new)
  Rails.configuration.event_store.subscribe_to_all_events(Events::LinkToActorStream.new)
end
