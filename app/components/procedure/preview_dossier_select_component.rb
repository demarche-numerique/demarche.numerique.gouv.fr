# frozen_string_literal: true

class Procedure::PreviewDossierSelectComponent < ApplicationComponent
  delegate :attestation_depot_requester_identity, :dossier_display_state, to: :helpers

  # dossiers: the sections of Procedure#preview_dossiers
  def initialize(dossiers:, selected:)
    @dossiers = dossiers
    @selected = selected
  end

  def render?
    @dossiers.present? && @selected.present?
  end

  def react_props
    {
      label: t('.label'),
      searchPlaceholder: t('.search'),
      sections:,
      value: @selected.id.to_s,
      data: { no_autosubmit: 'true', action: 'change->preview-dossier#select' },
    }
  end

  private

  def sections
    @dossiers.map do |revision, dossiers|
      { label: t(".section.#{revision}"), items: dossiers.map { [option_label(it), it.id.to_s] } }
    end
  end

  def option_label(dossier)
    t('.option', number: dossier.id, owner: attestation_depot_requester_identity(dossier), state: dossier_display_state(dossier).upcase)
  end
end
