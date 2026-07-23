# frozen_string_literal: true

# Shared by mutations (Mutations::BaseMutation) and query fields
# (Types::QueryType): resolves a FindDemarcheInput to a Procedure the caller
# is authorized on, or nil — one collapsed outcome for "does not exist" and
# "not yours", so the API never discloses the existence of someone else's
# démarche. Callers phrase their own action-specific error message. The
# mutations and query fields that still inline this resolution should
# migrate here.
module DemarcheAuthorizationConcern
  private

  def demarche_number(demarche)
    demarche.number.presence || ApplicationRecord.id_from_typed_id(demarche.id)
  end

  def find_authorized_demarche(demarche)
    procedure = Procedure.find_by(id: demarche_number(demarche))
    procedure if procedure.present? && context.authorized_demarche?(procedure)
  end
end
