# frozen_string_literal: true

module Events
  # Sync subscriber: links every dossier event to the stream of its démarche,
  # in the same transaction as the publish.
  class LinkToProcedureStream
    def call(event)
      return unless event.is_a?(Events::DossierEvent)

      Events.store.link(event.event_id, stream_name: Events.procedure_stream(event.procedure_id))
    end
  end
end
