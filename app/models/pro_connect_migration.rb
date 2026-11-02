# frozen_string_literal: true

class ProConnectMigration < ApplicationRecord
  PENDING_FOR = 30.minutes

  belongs_to :user

  enum :state, {
    started: 'started',
    same_email: 'same_email',
    domain_mismatch: 'domain_mismatch',
    existing_account: 'existing_account',
  }

  scope :pending, -> { started.where(created_at: PENDING_FOR.ago..) }
end
