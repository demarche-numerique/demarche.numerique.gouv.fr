# frozen_string_literal: true

class ProConnectMigration < ApplicationRecord
  PENDING_FOR = 30.minutes
  SUPPORT_STATES = ['domain_mismatch', 'existing_account'].freeze

  belongs_to :user

  enum :state, {
    started: 'started',
    same_email: 'same_email',
    domain_mismatch: 'domain_mismatch',
    existing_account: 'existing_account',
  }

  scope :pending, -> { started.where(created_at: PENDING_FOR.ago..) }
  scope :sent_to_support, -> { where(state: SUPPORT_STATES, updated_at: PENDING_FOR.ago..) }

  def identify!(auth:)
    update!(pro_connect_email: auth.email, state: outcome_for(auth.email))
  end

  def sent_to_support? = state.in?(SUPPORT_STATES)

  private

  def outcome_for(email)
    if email == source_email
      :same_email
    elsif domain(email) != domain(source_email)
      :domain_mismatch
    elsif User.exists?(email:)
      :existing_account
    else
      :started
    end
  end

  def domain(email) = email.split('@').last
end
