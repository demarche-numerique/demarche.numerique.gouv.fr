# frozen_string_literal: true

class TypesDeChamp::LinkTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  def self.icon = 'fr-icon-link'
  def self.feature_flag = :link_type_de_champ
  def self.private_only? = true
  def prefillable? = false
  # the editable component labels its input inside the callout
  def has_label? = false
end
