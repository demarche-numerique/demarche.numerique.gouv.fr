# frozen_string_literal: true

class Dossiers::CommentaireListComponent < ApplicationComponent
  include CommentaireHelper

  def initialize(dossier:, connected_user:, messagerie_seen_at: nil, instructeurs_seen_at: nil)
    @dossier = dossier
    @connected_user = connected_user
    @messagerie_seen_at = messagerie_seen_at
    @instructeurs_seen_at = instructeurs_seen_at
  end

  private

  attr_reader :dossier, :connected_user, :messagerie_seen_at, :instructeurs_seen_at

  def grouped_commentaires
    grouped_commentaires_by_date(dossier.preloaded_commentaires)
  end
end
