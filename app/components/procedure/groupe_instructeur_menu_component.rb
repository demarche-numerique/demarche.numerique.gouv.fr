# frozen_string_literal: true

class Procedure::GroupeInstructeurMenuComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def links
    links = [
      { name: t(".group_params"), url: '#parametres-groupe' },
      { name: t(".assigned_dossiers"), url: '#dossiers-affectes' },
      { name: t(".routing_rules"), url: '#regles-routage' },
      { name: t("views.shared.groupe_instructeurs.instructeur_assignation"), url: '#affectation-instructeurs' },
      { name: t(".contact_information"), url: '#informations-contact' },
    ]
    links.push({ name: t(".attestation_stamp"), url: '#tampon-attestation' }) if @procedure.attestation_acceptation_template&.activated?
    links
  end
end
