# frozen_string_literal: true

class Dossiers::AmiFollowComponentPreview < ViewComponent::Preview
  # La zone de consentement se charge à part, dans son turbo-frame : hors d'une
  # session connectée elle reste vide ici, cf. AmiConsentStateComponentPreview
  # pour ses différents états.
  def default
    render(previewed_component)
  end

  private

  # L'encart ne s'affiche qu'avec une démarche notifiant AMI et une identité
  # France Connect, que cette preview n'a pas : on force son affichage.
  def previewed_component
    Dossiers::AmiFollowComponent.new(dossier: nil).tap do |component|
      component.define_singleton_method(:render?) { true }
    end
  end
end
