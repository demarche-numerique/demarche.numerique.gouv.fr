# frozen_string_literal: true

class Dossiers::IndividualFormComponent < ApplicationComponent
  delegate :for_tiers?, to: :@dossier

  def initialize(dossier:)
    @dossier = dossier
  end

  def email_notifications?(individual)
    individual.object.notification_method == Individual.notification_methods[:email]
  end

  def can_personal_data_be_transmitted?
    @dossier.has_france_connect_type_de_champ? && current_user.france_connected_with_one_identity?
  end

  def identity_locked?
    !for_tiers? && @dossier.identity_from_fc?
  end

  def mandataire_identity_locked?
    @dossier.identity_from_fc?
  end

  private

  def back_url
    helpers.commencer_path(path: @dossier.procedure.path)
  end
end
