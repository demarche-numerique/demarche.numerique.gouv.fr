# frozen_string_literal: true

class Dossiers::DegradedIdentiteEntrepriseComponentPreview < ViewComponent::Preview
  def default
    profile = 'instructeur'

    component = Dossiers::DegradedIdentiteEntrepriseComponent.new(siret: '12345678901234', profile:)

    render_with_template(
      template: 'dossiers/external_champ_component_preview/default',
      locals: { component: }
    )
  end
end
