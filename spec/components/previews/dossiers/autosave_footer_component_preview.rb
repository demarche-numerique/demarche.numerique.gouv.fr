# frozen_string_literal: true

class Dossiers::AutosaveFooterComponentPreview < ViewComponent::Preview
  def brouillon
    render(component_for(state: 'brouillon'))
  end

  def en_construction
    render(component_for(state: 'en_construction'))
  end

  def annotations
    render(component_for(state: 'brouillon', annotation: true))
  end

  def brouillon_server_error
    render_error('brouillon', 'server')
  end

  def brouillon_auth_error
    render_error('brouillon', 'auth')
  end

  def brouillon_network_error
    render_error('brouillon', 'network')
  end

  def en_construction_server_error
    render_error('en_construction', 'server')
  end

  def annotations_server_error
    render_error('brouillon', 'server', annotation: true)
  end

  private

  def component_for(state:, annotation: false)
    dossier = Dossier.new(state:)
    Dossiers::AutosaveFooterComponent.new(dossier:, annotation:, owner: User.new)
  end

  def render_error(state, error_type, annotation: false)
    render_with_template(
      template: 'dossiers/autosave_footer_component_preview/error',
      locals: { component: component_for(state:, annotation:), error_type: }
    )
  end
end
