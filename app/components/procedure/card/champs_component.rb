# frozen_string_literal: true

class Procedure::Card::ChampsComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
    @count = @procedure.draft_revision.type_de_champs.count(&:public?)
  end

  private

  def error_messages
    @procedure.errors.messages_for(:public_draft_type_de_champs).to_sentence
  end

  def badge
    if error_messages.present?
      { label: 'À modifier', variant: :error }
    elsif @count == 0
      { label: 'À faire', variant: :warning }
    else
      { label: 'Validé', variant: :success }
    end
  end
end
