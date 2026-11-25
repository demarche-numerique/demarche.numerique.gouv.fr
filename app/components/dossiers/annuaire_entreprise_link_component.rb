# frozen_string_literal: true

class Dossiers::AnnuaireEntrepriseLinkComponent < ApplicationComponent
  attr_reader :siret, :extra_class_names

  def initialize(siret:, extra_class_names: nil)
    @siret, @extra_class_names = siret, extra_class_names
  end

  def call
    link_to t('.more_information'),
      helpers.annuaire_link(siret),
      **helpers.external_link_attributes(t('.more_information')).merge(class: Array.wrap(extra_class_names).append('fr-link'))
  end
end
