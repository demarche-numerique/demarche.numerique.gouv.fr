# frozen_string_literal: true

class Champs::QuotientFamilialChamp < Champ
  REFRESH_DELAY = 24.hours

  attr_accessor :preview_state

  def fc_data_approved? = ActiveModel::Type::Boolean.new.cast(value)

  def fc_data_correct?
    fetched? && fc_data_approved?
  end

  def fc_data_incorrect?
    fetched? && fc_data_approved? == false
  end

  def fc_data_not_found?
    external_error? && self.fetch_external_data_exceptions.first&.code == 404
  end

  def ready_for_external_call?
    dossier.user_from_france_connect? && !dossier.for_tiers? && dossier.procedure.for_individual? && !dossier.for_procedure_preview?
  end

  def fetch_external_data
    fci = dossier.user.france_connect_informations.first
    api = APIParticulier::QuotientFamilial.new(procedure)
    api.quotient_familial(fci)
  end

  def update_external_data!(data)
    hash = {
      data: { api_part: data },
      value_json: { api_part: extract_value_json(data:) },
    }
    super(hash)
  end

  def clear_piece_justificative
    if fc_data_correct? && self.piece_justificative_file.attached?
      self.piece_justificative_file.purge_later
    end
  end

  def libelle
    if fc_data_correct?
      ""
    elsif fc_data_incorrect? || external_error? || idle?
      I18n.t('api_particulier.libelle.quotient_familial.piece_justificative')
    else
      I18n.t('api_particulier.libelle.quotient_familial.default')
    end
  end

  private

  def extract_value_json(data:)
    if (qf_data = data[:quotient_familial])
      extract_qf_data = {
        fournisseur: qf_data[:fournisseur],
        valeur: qf_data[:valeur],
        periode_effective: Date.new(qf_data[:annee], qf_data[:mois]).iso8601,
        periode_calcul: Date.new(qf_data[:annee_calcul], qf_data[:mois_calcul]).iso8601,
      }

      data.merge(quotient_familial: extract_qf_data)
    else
      data
    end
  end
end
