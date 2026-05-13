# frozen_string_literal: true

class UserProcedurePresentation < ApplicationRecord
  belongs_to :user
  belongs_to :procedure

  attribute :displayed_columns, :column, array: true
end
