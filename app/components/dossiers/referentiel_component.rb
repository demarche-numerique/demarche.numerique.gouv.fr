# frozen_string_literal: true

class Dossiers::ReferentielComponent < Referentiels::ReferentielDisplayBaseComponent
  attr_reader :champ, :profile

  def initialize(champ:, profile:)
    @champ = champ
    @profile = profile
  end

  def call
    if champ.external_id.blank? && champ.value.blank? # exact_match remplit external_id, autocomplete remplit value
      tag.p(t('not_filled', scope: 'activerecord.attributes.type_de_champ'), class: "fr-mt-1w")
    # fetched? ne couvre que la correspondance exacte : l'autocomplétion écrit value_json sans
    # passer par la machine à états. TODO: ne garder que fetched? quand elle y passera.
    elsif champ.fetched? || champ.value_json.present?
      render Dossiers::ExternalChampComponent.new(data:, source:)
    elsif champ.pending?
      tag.p(t('shared.champs.external_data.pending', identifier: champ.external_id), class: "fr-mt-1w")
    elsif champ.external_data_not_found?
      tag.p(t('shared.champs.external_data.not_found', identifier: champ.external_id), class: "fr-mt-1w")
    elsif champ.external_error?
      tag.p(t('shared.champs.external_data.error', identifier: champ.external_id), class: "fr-mt-1w")
    end
  end

  private

  def data
    [['Identifiant', champ.to_s]] +
    data_source.filter_map do |jsonpath, _mapping|
      value = format(jsonpath, safe_value_json.dig(jsonpath))
      [libelle(jsonpath), value]
    end
  end

  def data_source
    if profile == 'instructeur'
      referentiel_mapping_displayable_for_instructeur
    else
      referentiel_mapping_displayable_for_usager
    end
  end

  def source
    tag.acronym("Référentiel Externe")
  end
end
