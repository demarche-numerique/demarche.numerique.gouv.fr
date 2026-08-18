# frozen_string_literal: true

class Dossiers::AmiConsentStateComponentPreview < ViewComponent::Preview
  def loading
    render(Dossiers::AmiConsentStateComponent.new(status: :loading))
  end

  def not_granted
    render(Dossiers::AmiConsentStateComponent.new(status: :not_granted))
  end

  def granted
    render(Dossiers::AmiConsentStateComponent.new(status: :granted))
  end

  def error
    render(Dossiers::AmiConsentStateComponent.new(status: :not_granted, error: true))
  end
end
