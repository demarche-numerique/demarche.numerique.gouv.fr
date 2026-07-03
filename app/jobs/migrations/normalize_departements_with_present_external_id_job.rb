# frozen_string_literal: true

class Migrations::NormalizeDepartementsWithPresentExternalIdJob < ApplicationJob
  def perform(ids)
    ChampData.where(type: "Champs::DepartementChamp").where(id: ids).find_each do |champ|
      next if champ.external_id.blank?

      if champ.value.blank?
        champ.update_columns(value: APIGeoService.departement_name(champ.external_id))
      elsif (match = champ.value.match(/^(\w{2,3}) - (.+)/))
        code = match[1]
        name = APIGeoService.departement_name(code)
        champ.update_columns(external_id: code, value: name)
      end
    end
  end
end
