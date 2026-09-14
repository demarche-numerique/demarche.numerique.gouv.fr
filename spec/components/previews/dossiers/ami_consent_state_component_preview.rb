# frozen_string_literal: true

class Dossiers::AmiConsentStateComponentPreview < ViewComponent::Preview
  def loading
    render(Dossiers::AmiConsentStateComponent.new(status: :loading))
  end

  def not_granted
    render(Dossiers::AmiConsentStateComponent.new(status: :not_granted, dossier: previewed_dossier))
  end

  def granted
    render(Dossiers::AmiConsentStateComponent.new(status: :granted))
  end

  private

  # Le formulaire a besoin d'un dossier pour construire son action, mais rien
  # d'autre : un dossier non persisté suffit à cette preview.
  def previewed_dossier = Dossier.new(id: 1)
end
