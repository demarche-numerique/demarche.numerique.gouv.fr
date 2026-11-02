# frozen_string_literal: true

module Events
  class ProcedureEvent < RubyEventStore::Event
    def procedure_id = data.fetch(:procedure_id)
  end
end
