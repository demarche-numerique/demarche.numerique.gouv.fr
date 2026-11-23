# frozen_string_literal: true

class Sources::LaidOutRevision < GraphQL::Dataloader::Source
  def fetch(revisions)
    ProcedureRevision.preload_type_de_champs(revisions.reject(&:type_de_champs_laid_out?))
    revisions
  end
end
