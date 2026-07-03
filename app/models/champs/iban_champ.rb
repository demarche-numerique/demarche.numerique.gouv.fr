# frozen_string_literal: true

class Champs::IbanChamp < Champ
  validates_with IbanValidator, if: :should_validate_in_current_context?
  after_validation :format_iban

  private

  def format_iban
    self.value = value&.gsub(/\s+/, '')&.gsub(/(.{4})/, '\0 ')
  end
end
