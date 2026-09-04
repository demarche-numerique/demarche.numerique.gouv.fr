# frozen_string_literal: true

class Dossiers::InvalidIneligibiliteRulesComponent < ApplicationComponent
  def initialize(dossier:, wrapped: true)
    @dossier = dossier
    @revision = dossier.revision
    @wrapped = wrapped
  end

  private

  attr_reader :dossier

  def render?
    dossier.revision.ineligibilite_enabled?
  end

  def error_message
    dossier.revision.ineligibilite_message
  end

  def opened? = dossier.ineligibilite_triggered_by_answered_champs?
  def wrapped? = @wrapped
end
