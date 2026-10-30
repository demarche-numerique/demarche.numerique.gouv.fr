# frozen_string_literal: true

class RIB
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :account_holder, :string
  attribute :account_holder_name, :string
  attribute :account_holder_address, :string
  attribute :bank_name, :string
  attribute :bic, :string
  attribute :iban, :string

  def to_h
    { account_holder:, bank_name:, bic:, iban: }
  end
end
