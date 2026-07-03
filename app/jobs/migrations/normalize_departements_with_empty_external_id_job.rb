# frozen_string_literal: true

class Migrations::NormalizeDepartementsWithEmptyExternalIdJob < ApplicationJob
  def perform(ids)
    ChampData.where(type: "Champs::DepartementChamp").where(id: ids).find_each do |champ|
      next unless champ.external_id == ''

      if champ.value.nil?
        champ.update_columns(external_id: nil)
      elsif champ.value == ''
        champ.update_columns(external_id: nil, value: nil)
      elsif champ.value == '85'
        champ.update_columns(external_id: '85', value: 'Vendée')
      elsif champ.value.present?
        match = champ.value.match(/^(\w{2,3}) - (.+)/)
        if match
          code = match[1]
          name = APIGeoService.departement_name(code)
          champ.update_columns(external_id: code, value: name)
        else
          champ.update_columns(external_id: APIGeoService.departement_code(champ.value))
        end
      end
    end
  end
end
