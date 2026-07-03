# frozen_string_literal: true

class Migrations::NormalizeCommunesJob < ApplicationJob
  def perform(ids)
    ChampData.where(type: "Champs::CommuneChamp").where(id: ids).find_each do |champ|
      if champ.external_id.blank?
        champ.value = nil
        champ.value_json = {}
        champ.save!
      else
        value_json = champ.value_json || {}

        if !champ.departement? || champ.code_departement == 'undefined' || champ.code_departement == '99'
          metro_code = champ.external_id[0..1]
          drom_com_code = champ.external_id[0..2]

          if metro_code == '97' || metro_code == '98'
            value_json[:code_departement] = drom_com_code
          else
            value_json[:code_departement] = metro_code
          end
        end

        if !champ.code_postal? && code_postal_with_fallback(champ).present?
          value_json[:code_postal] = code_postal_with_fallback(champ)
        end

        if value_json.present?
          champ.update_column(:value_json, value_json)
        end
      end
    end
  end

  private

  # We try to extract the postal code from the value, which is the name of the commune and the
  # postal code in brackets.
  def code_postal_with_fallback(champ)
    if champ.value.present?
      match = champ.value.match(/[^(]\(([^\)]*)\)$/)
      match[1] if match.present?
    else
      nil
    end
  end
end
