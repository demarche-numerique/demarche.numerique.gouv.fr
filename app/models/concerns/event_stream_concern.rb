# frozen_string_literal: true

# A record with a stream in the event store, named after it (Dossier$<id>).
module EventStreamConcern
  extend ActiveSupport::Concern

  # Appends the event to the stream of the record, with its id in the data.
  def publish_event(event_class, author: nil, **data)
    event = event_class.new(data: { :"#{model_name.singular}_id" => id, **data })
    Events.publish(event, stream_name: Events.stream(model_name.name, id), author:)
  end
end
