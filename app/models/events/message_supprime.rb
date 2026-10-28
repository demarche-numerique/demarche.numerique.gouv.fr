# frozen_string_literal: true

module Events
  # A message retracted by its sender (instructeur or expert): discarded,
  # body and attachment removed. data: commentaire_id
  class MessageSupprime < DossierEvent
  end
end
