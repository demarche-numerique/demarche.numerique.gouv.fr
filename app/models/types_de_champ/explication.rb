# frozen_string_literal: true

class TypesDeChamp::Explication < TypesDeChamp::Text
  def self.category = STRUCTURE
  def self.option_keys = [:collapsible_explanation_enabled, :collapsible_explanation_text]

  validates :notice_explicative, content_type: -> (_record) { AUTHORIZED_CONTENT_TYPES }, size: { less_than: 20.megabytes }, on: :update
  validates :notice_explicative, empty_file: true, on: :update

  def prefillable? = false
  def fillable? = false
  def libelle_optionnal? = true
  def has_label? = false
  def tags_for_template = [].freeze
  def customizable? = false
  store_accessor :options, :collapsible_explanation_enabled, :collapsible_explanation_text
  boolean_options :collapsible_explanation_enabled
end
