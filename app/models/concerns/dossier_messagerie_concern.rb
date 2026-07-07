# frozen_string_literal: true

module DossierMessagerieConcern
  extend ActiveSupport::Concern

  included do
    has_many :unread_commentaires_for_user,
      -> { sent_by_agent.unread_by_recipient },
      class_name: 'Commentaire',
      inverse_of: :dossier
  end

  # Un message « nouveau message » est un message d'agent non lu par l'usager.
  # Il est volontairement en retrait derrière les deux notifications prioritaires
  # « à corriger » et « en attente de réponse » (qui sont aussi des messages d'agent
  # non lus) pour n'afficher qu'un seul badge de type messagerie à la fois.
  def unread_message_for_user?
    return false if pending_correction? || pending_response?

    # `.any?` lit l'association préchargée en mémoire (aucune requête dans la
    # liste, cf. USER_LIST_PRELOADS), et retombe sur un `exists?` léger sinon.
    unread_commentaires_for_user.any?
  end
end
