# frozen_string_literal: true

module Events
  class AdministrateurEvent < RubyEventStore::Event
    def administrateur_id = data.fetch(:administrateur_id)
  end
end
