# frozen_string_literal: true

module DossierValidateConcern
  extend ActiveSupport::Concern

  # Autosave's _ensure_no_duplicate_errors calls errors.uniq! after validations,
  # which would collapse same-attribute, same-type errors imported from
  # different champs. Include the champ in the error identity to prevent that.
  class ChampNestedError < ActiveModel::NestedError
    protected def attributes_for_hash
      [*super, inner_error.base]
    end
  end

  included do
    validate :validate_champs_public_value, on: :champs_public_value
    validate :validate_champs_private_value, on: :champs_private_value
    validate :validate_champs_public_completeness, on: :champs_public_completeness
    validate :validate_champs_private_completeness, on: :champs_private_completeness
  end

  def champs_public_valid?
    validate(:champs_public_completeness)
  end

  def champs_private_valid?
    validate(:champs_private_completeness)
  end

  private

  def validate_champs_public_value
    validate_projected_champs(flat_public_champs, :champ_value)
  end

  def validate_champs_private_value
    validate_projected_champs(flat_private_champs, :champ_value)
  end

  def validate_champs_public_completeness
    validate_projected_champs(flat_public_champs, [:champ_value, :champ_completeness])
  end

  def validate_champs_private_completeness
    validate_projected_champs(flat_private_champs, [:champ_value, :champ_completeness])
  end

  # Both contexts must be validated in a single call: champ.validate clears
  # previous errors, so a second pass would erase the first one's errors.
  def validate_projected_champs(champs, contexts)
    champs.each do |champ|
      next if champ.validate(contexts)
      champ.errors.each { errors.objects.append(ChampNestedError.new(self, it)) }
    end
  end
end
