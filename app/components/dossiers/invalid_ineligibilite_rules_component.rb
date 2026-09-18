# frozen_string_literal: true

class Dossiers::InvalidIneligibiliteRulesComponent < ApplicationComponent
  def initialize(dossier:, wrapped: true)
    @dossier = dossier
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

  # The alert only speaks about champs the usager wrote. Each read walks the
  # whole rule tree; ||= would not memoize a false.
  def opened?
    return @opened if defined?(@opened)

    @opened = !dossier.can_submit_modifications?
  end

  def wrapped? = @wrapped
end
