# frozen_string_literal: true

class PrefillIdentity
  attr_reader :dossier, :params

  def initialize(dossier, params)
    @dossier = dossier
    @params = params
  end

  def to_h
    return {} if !dossier.procedure.for_individual?

    {
      prenom: params["identite_prenom"],
      nom: params["identite_nom"],
      gender: gender_param,
    }
  end

  private

  def gender_param
    return if dossier.procedure.no_gender?

    valid_genders = [Individual::GENDER_MALE, Individual::GENDER_FEMALE]
    params["identite_genre"].presence_in(valid_genders)
  end
end
