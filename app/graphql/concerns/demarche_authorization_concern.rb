# frozen_string_literal: true

# nil both when the démarche does not exist and when the caller has no access
# to it, so the API does not disclose its existence.
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
