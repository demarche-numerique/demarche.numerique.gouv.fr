# frozen_string_literal: true

class Procedure::LegacyDeclarativeEmailsNoticeComponent < ApplicationComponent
  MODAL_ID = 'switch-to-combined-declarative-emails'

  def initialize(procedure:)
    @procedure = procedure
  end

  def render?
    @procedure.legacy_declarative_emails?
  end

  private

  attr_reader :procedure

  def declarative_state
    procedure.declarative_accepte? ? :accepte : :en_instruction
  end
end
