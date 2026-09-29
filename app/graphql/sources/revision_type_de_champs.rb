# frozen_string_literal: true

# Lays out the types de champ of every revision of the response in one query.
class Sources::RevisionTypeDeChamps < GraphQL::Dataloader::Source
  def fetch(revisions)
    ProcedureRevision.preload_type_de_champs(revisions)
    revisions
  end
end
