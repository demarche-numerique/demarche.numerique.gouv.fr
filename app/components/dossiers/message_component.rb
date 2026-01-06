# frozen_string_literal: true

class Dossiers::MessageComponent < ApplicationComponent
  include DossierHelper

  def initialize(commentaire:, connected_user:, messagerie_seen_at: nil, groupe_gestionnaire: nil, heading_level: 'h2', instructeurs_seen_at: nil)
    @commentaire = commentaire
    @connected_user = connected_user
    @messagerie_seen_at = messagerie_seen_at
    @groupe_gestionnaire = groupe_gestionnaire
    @heading_level = heading_level
    @instructeurs_seen_at = instructeurs_seen_at
  end

  attr_reader :commentaire, :connected_user, :messagerie_seen_at, :groupe_gestionnaire
  def heading_level
    @heading_level
  end

  def correction_badge
    return if groupe_gestionnaire || commentaire.dossier_correction.nil?

    if commentaire.dossier_correction.cancelled?
      helpers.correction_resolved_badge(:discarded)
    elsif commentaire.dossier_correction.resolved?
      type = if commentaire.dossier_correction.resolved_by_modification?
        :modified
      else
        :not_modified
      end

      helpers.correction_resolved_badge(type)
    else
      helpers.pending_correction_badge(connected_user.is_a?(Instructeur) ? :for_instructeur : :for_user)
    end
  end

  def response_badge
    return if groupe_gestionnaire || commentaire.dossier_pending_response.nil?

    if commentaire.dossier_pending_response.responded?
      # Don't show any badge if the message was deleted
      return if commentaire.discarded?

      helpers.response_resolved_badge(:responded)
    else
      helpers.pending_response_badge(connected_user.is_a?(Instructeur) ? :for_instructeur : :for_user)
    end
  end

  def commentaire_class(commentaire, connected_user)
    if commentaire.sent_by_system?
      'fr-background-alt--grey'
    elsif commentaire.sent_by_usager?
      'fr-background-alt--brown-cafe-creme'
    else
      'fr-background-alt--blue-cumulus'
    end
  end

  private

  def soft_deletable?
    commentaire.soft_deletable?(connected_user)
  end

  def delete_button_text
    if groupe_gestionnaire.nil? && commentaire.dossier_pending_response&.pending?
      t('.delete_with_response_button')
    else
      t('.delete_button')
    end
  end

  def show_cancel_correction_button?
    return false if groupe_gestionnaire
    return false unless connected_user.is_a?(Instructeur)

    commentaire.can_cancel_correction?(connected_user)
  end

  def show_delete_button?
    # For groupe_gestionnaire, gestionnaires can delete their own messages
    # For dossiers, only instructeurs can delete their own messages
    return false if groupe_gestionnaire.nil? && !connected_user.is_a?(Instructeur)

    commentaire.soft_deletable?(connected_user)
  end

  def cancel_correction_url
    cancel_correction_instructeur_commentaire_path(
      commentaire.dossier.procedure,
      commentaire.dossier,
      commentaire,
      statut: params[:statut]
    )
  end

  def highlight_if_unseen_class
    if highlight?
      'highlighted'
    end
  end

  def scroll_to_target
    if highlight?
      { scroll_to_target: 'to' }
    end
  end

  def icon
    if commentaire.sent_by_system?
      dsfr_icon('fr-icon-mail-fill icon-sm-for-xs')
    elsif commentaire.sent_by_usager?
      dsfr_icon('fr-icon-folder-user-fill icon-sm-for-xs')
    else
      dsfr_icon('fr-icon-user-fill icon-sm-for-xs')
    end
  end

  def commentaire_issuer
    issuer = if commentaire.sent_by_system?
      t('.automatic_email')
    elsif commentaire.sent_by_usager?
      demandeur_dossier(commentaire.dossier).presence || t('.applicant')
    elsif groupe_gestionnaire
      commentaire.gestionnaire_id ? commentaire.gestionnaire_email : commentaire.sender_email
    else
      commentaire.redacted_email
    end

    if commentaire.sent_by?(connected_user)
      "[#{t('.you')}] #{issuer}"
    else
      issuer
    end
  end

  def commentaire_from_guest?
    groupe_gestionnaire ? false : commentaire.dossier.invites.map(&:email).include?(commentaire.email)
  end

  def commentaire_date
    I18n.l(commentaire.created_at, format: :short_datetime)
  end

  def delete_url
    groupe_gestionnaire ? gestionnaire_groupe_gestionnaire_commentaire_path(groupe_gestionnaire, commentaire, statut: params[:statut]) : instructeur_commentaire_path(commentaire.dossier.procedure, commentaire.dossier, commentaire, statut: params[:statut])
  end

  def highlight?
    commentaire.persisted? && (messagerie_seen_at.nil? || messagerie_seen_at < commentaire.created_at)
  end

  def read_by_recipient?
    return false if !commentaire.persisted?
    return false if !sent_by_connected_user?
    commentaire.seen_by_recipient_at.present?
  end

  def sent_by_connected_user?
    if commentaire.sent_by_usager?
      connected_user.is_a?(User) && commentaire.sent_by?(connected_user)
    elsif commentaire.sent_by_instructeur?
      connected_user.is_a?(Instructeur) && commentaire.sent_by?(connected_user)
    elsif commentaire.sent_by_expert?
      connected_user.is_a?(Expert) && commentaire.sent_by?(connected_user)
    else
      false
    end
  end

  def show_attachments?
    return false if commentaire.discarded?

    commentaire.piece_jointe.attached?
  end
end
