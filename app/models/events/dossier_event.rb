# frozen_string_literal: true

module Events
  class DossierEvent < RubyEventStore::Event
    def dossier_id = data.fetch(:dossier_id)

    def procedure_id = data.fetch(:procedure_id)
  end
end
