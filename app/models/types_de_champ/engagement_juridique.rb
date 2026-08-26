# frozen_string_literal: true

class TypesDeChamp::EngagementJuridique < TypeDeChamp
  def self.category = REFERENTIEL_EXTERNE
  def self.feature_flag = :engagement_juridique_type_de_champ
  def self.private_only? = true
end
