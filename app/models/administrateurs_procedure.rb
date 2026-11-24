# frozen_string_literal: true

class AdministrateursProcedure < ApplicationRecord
  belongs_to :administrateur
  belongs_to :procedure

  scope :without_support, -> { where(manager: [false, nil]) }
end
