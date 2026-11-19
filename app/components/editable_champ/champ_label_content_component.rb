# frozen_string_literal: true

class EditableChamp::ChampLabelContentComponent < ApplicationComponent
  include ApplicationHelper

  def initialize(form:, champ:, seen_at: nil, row_number: nil)
    @form, @champ, @seen_at, @row_number = form, champ, seen_at, row_number
  end

  def render_libelle?
    !@champ.france_connect?
  end

  def highlight_if_unseen_class
    if highlight?
      'highlighted'
    end
  end

  def highlight?
    @champ.value_updated_at.present? && @seen_at&.<(@champ.value_updated_at)
  end

  def rebased?
    return false if @champ.rebased_at.blank?
    return false if @champ.rebased_at <= (@seen_at || @champ.value_updated_at)
    return false if !current_user.owns_or_invite?(@champ.dossier)
    return false if @champ.dossier.for_procedure_preview?

    true
  end
end
