# frozen_string_literal: true

class EditableChamp::ProposedPrefillComponent < ApplicationComponent
  def initialize(champ:)
    @champ = champ
  end

  def render?
    @champ.referentiel? && @champ.proposes_public_changes?
  end

  def changed_columns
    @champ.dossier.instructeur_changed_columns
  end

  def submit_path
    proposition_instructeur_dossier_path(@champ.dossier.procedure, @champ.dossier)
  end
end
