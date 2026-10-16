# frozen_string_literal: true

module Events
  # A message in the messagerie, by the usager, an instructeur or an expert;
  # system messages are not recorded. data: commentaire_id
  class MessageCree < DossierEvent
  end
end
