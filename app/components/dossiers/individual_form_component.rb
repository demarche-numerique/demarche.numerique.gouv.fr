# frozen_string_literal: true

class Dossiers::IndividualFormComponent < ApplicationComponent
  delegate :for_tiers?, to: :@dossier

  def initialize(dossier:, pro_connect: false)
    @dossier = dossier
    @identity_source = IdentityPrefillSource.new(dossier:, pro_connect:)
  end

  def email_notifications?(individual)
    individual.object.notification_method == Individual.notification_methods[:email]
  end

  def can_personal_data_be_transmitted?
    @dossier.has_france_connect_type_de_champ? && current_user.france_connected_with_one_identity?
  end

  def individual_field_locked?(field) = @identity_source.individual_field_locked?(field)

  def individual_identity_locked? = @identity_source.individual_locked_fields.any?

  def mandataire_identity_locked? = @identity_source.mandataire_locked?

  def identity_locked_message
    case @identity_source.name
    when :france_connect then t('.identity_locked_by_france_connect')
    when :pro_connect then t('.identity_locked_by_pro_connect')
    end
  end

  private

  def back_url
    helpers.commencer_path(path: @dossier.procedure.path)
  end
end
