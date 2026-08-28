# frozen_string_literal: true

class Dossiers::AmiFollowComponentPreview < ViewComponent::Preview
  # La zone de consentement se charge à part, dans son turbo-frame : elle reste
  # vide ici, cf. AmiConsentStateComponentPreview pour ses différents états.
  def default
    render(previewed_component)
  end

  private

  # L'encart demande une démarche notifiant AMI et une identité France Connect,
  # que cette preview n'a pas : on force son affichage, et on la prive de
  # l'adresse du turbo-frame, qu'elle ne pourrait pas charger sans session.
  def previewed_component
    Dossiers::AmiFollowComponent.new(dossier: nil).tap do |component|
      component.define_singleton_method(:render?) { true }
      component.define_singleton_method(:consent_path) { nil }
    end
  end
end
