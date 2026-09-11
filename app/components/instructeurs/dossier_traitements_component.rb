# frozen_string_literal: true

class Instructeurs::DossierTraitementsComponent < ApplicationComponent
  attr_reader :traitements

  def initialize(traitements:)
    @traitements = traitements
  end

  def traitement_props(traitement)
    processed_at = l(traitement.processed_at, format: :long_with_time)
    { processed_at:, email: traitement.instructeur_email.presence || t('.instructeur_inconnu') }
  end
end
