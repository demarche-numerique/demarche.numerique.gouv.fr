# frozen_string_literal: true

class TypesDeChamp::TextareaTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  def self.icon = 'fr-icon-align-left'
  MINIMUM_TEXTAREA_CHARACTER_LIMIT_LENGTH = 400

  def self.option_keys = [:character_limit]

  store_accessor :options, :character_limit

  validates :character_limit, numericality: {
    greater_than_or_equal_to: MINIMUM_TEXTAREA_CHARACTER_LIMIT_LENGTH,
    only_integer: true,
    allow_blank: true,
  }

  def revision_diff_options = { character_limit: RevisionDiffValue.new(character_limit.presence) { character_limit } }

  def customizable? = false
  def character_limit? = character_limit.present?

  def estimated_fill_duration(revision)
    FILL_DURATION_MEDIUM
  end
end
