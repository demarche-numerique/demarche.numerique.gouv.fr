# frozen_string_literal: true

class Sources::DossierLinkProcedures < GraphQL::Dataloader::Source
  include Columns::DossierLinkProcedureLookup

  def fetch(champs)
    load_linked_procedures(champs.filter_map { linked_procedure_id(it) }.uniq)
    champs.map { nil }
  end
end
