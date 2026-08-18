# frozen_string_literal: true

# Partie de l'encart AMI qui dépend du consentement de l'usager : elle est
# chargée puis rafraîchie dans un turbo-frame, l'état venant d'AMI.
class Dossiers::AmiConsentStateComponent < ApplicationComponent
  # :loading tant qu'AMI n'a pas répondu, :unknown quand il n'a pas su répondre,
  # :unavailable quand on ne peut pas lui demander
  STATUSES = [:loading, :granted, :not_granted, :unknown, :unavailable].freeze

  def initialize(status:, error: false, focus: false)
    @status = status
    @error = error
    @focus = focus
  end

  def render? = @status != :unavailable

  def loading? = @status == :loading

  def granted? = @status == :granted

  def error? = @error.present?

  def app_name = Ami::APP_NAME

  # Le focus n'est déplacé qu'après une action de l'usager, jamais au
  # chargement de la page.
  def granted_attributes
    return {} if !@focus

    { tabindex: "-1", data: { controller: "autofocus" } }
  end
end
