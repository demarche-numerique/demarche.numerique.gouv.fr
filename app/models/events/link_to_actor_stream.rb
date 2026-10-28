# frozen_string_literal: true

module Events
  # Sync subscriber: links every event with an actor to the stream of that
  # account, in the same transaction as the publish.
  class LinkToActorStream
    def call(event)
      actor = event.metadata[:actor]
      return if actor.nil?

      Events.store.link(event.event_id, stream_name: Events.stream(actor[:type], actor[:id]))
    rescue RubyEventStore::EventDuplicatedInStream
      # already appended to the account's own stream
    end
  end
end
