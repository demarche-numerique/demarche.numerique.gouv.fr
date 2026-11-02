# frozen_string_literal: true

# Domain events, recorded in the event store (Rails Event Store) inside the
# business transaction that produces them, except the removal of a démarche
# (Procedure#discard_and_keep_track!), which has none. Events are thin: ids
# and the actor, never champ values, message bodies or emails.
#
# Every event of a dossier is appended to its own stream and linked to the
# stream of its démarche; the events of a démarche are appended to that
# stream. An event with an actor is also linked to the stream of that
# account (Instructeur$<id>, Expert$<id>, Administrateur$<id>, User$<id>,
# SuperAdmin$<id>), which thereby holds everything done by and about it.
module Events
  def self.store = Rails.configuration.event_store

  def self.stream(type, id) = "#{type}$#{id}"

  def self.dossier_stream(dossier_id) = stream("Dossier", dossier_id)

  def self.procedure_stream(procedure_id) = stream("Procedure", procedure_id)

  # Call inside the business transaction, in causal order.
  def self.publish(event, stream_name:, author: nil)
    store.with_metadata(actor_metadata(author)) do
      store.publish(event, stream_name:)
    end
    event
  end

  # Metadata for the person behind an event; an automatic operation has none.
  def self.actor_metadata(author)
    return {} if author.nil? || author.is_a?(Symbol)

    { actor: { type: author.class.name, id: author.id } }
  end
end
