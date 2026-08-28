# frozen_string_literal: true

# Partie de l'encart AMI qui dépend du consentement de l'usager : elle est
# chargée puis rafraîchie dans un turbo-frame, l'état venant d'AMI.
class Dossiers::AmiConsentStateComponent < ApplicationComponent
  # status vient de Ami::ConsentStatus (:loading tant qu'AMI n'a pas répondu,
  # :unknown quand il n'a pas su répondre, :unavailable quand on ne peut pas lui
  # demander) ou de Ami::GrantConsent (:error quand l'écriture a échoué).
  def initialize(status:, dossier: nil, focus: false)
    @status = status
    @dossier = dossier
    @focus = focus
  end

  # Le consentement vaut pour toutes les démarches, mais se donne depuis le
  # dossier affiché, dont l'événement suit l'acceptation.
  def form_path = create_ami_consent_dossier_path(@dossier)

  def render? = @status != :unavailable

  def loading? = @status == :loading

  def granted? = @status == :granted

  def error? = @status == :error

  def app_name = Ami::APP_NAME

  # Le focus n'est déplacé qu'après une action de l'usager, jamais au
  # chargement de la page.
  def granted_attributes
    return {} if !@focus

    { tabindex: "-1", data: { controller: "autofocus" } }
  end
end
