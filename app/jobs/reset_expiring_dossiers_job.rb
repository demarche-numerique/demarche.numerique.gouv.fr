# frozen_string_literal: true

class ResetExpiringDossiersJob < ApplicationJob
  queue_as :low
  def perform(procedure)
    procedure
      .dossiers
      .in_batches do |relation|
      relation.each(&:reset_removal!)
    end
  end
end
