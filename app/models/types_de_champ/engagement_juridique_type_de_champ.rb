# frozen_string_literal: true

class TypesDeChamp::EngagementJuridiqueTypeDeChamp < TypeDeChamp
  def self.category = REFERENTIEL
  def self.icon = 'fr-icon-verified-badge-line'
  def self.feature_flag = :engagement_juridique_type_de_champ
  def self.private_only? = true
end
