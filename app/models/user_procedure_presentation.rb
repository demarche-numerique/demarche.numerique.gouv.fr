# frozen_string_literal: true

class UserProcedurePresentation < ApplicationRecord
  belongs_to :user
  belongs_to :procedure

  attribute :displayed_columns, :column, array: true

  validates :user_id, uniqueness: { scope: :procedure_id }
  validates_associated :displayed_columns
end
