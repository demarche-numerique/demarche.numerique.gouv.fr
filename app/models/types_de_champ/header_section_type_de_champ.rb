# frozen_string_literal: true

# Its level is its place in the tree: how deep it sits in the header sections
# of its block (TypeDeChamp#block_level).
class TypesDeChamp::HeaderSectionTypeDeChamp < TypeDeChamp
  def self.category = STRUCTURE
  def self.icon = 'fr-icon-heading'

  def fillable? = false
  def description_configurable? = false
  def has_label? = false
  def tags_for_template = [].freeze
end
