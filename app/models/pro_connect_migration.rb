# frozen_string_literal: true

class ProConnectMigration < ApplicationRecord
  PENDING_FOR = 30.minutes
  SUPPORT_STATES = ['domain_mismatch', 'existing_account'].freeze
  CODE_VALIDITY = 10.minutes
  MAX_CODE_ATTEMPTS = 5

  belongs_to :user

  enum :state, {
    started: 'started',
    same_email: 'same_email',
    domain_mismatch: 'domain_mismatch',
    existing_account: 'existing_account',
    awaiting_code: 'awaiting_code',
  }

  scope :pending, -> { started.where(created_at: PENDING_FOR.ago..) }
  scope :sent_to_support, -> { where(state: SUPPORT_STATES, updated_at: PENDING_FOR.ago..) }

  def identify!(auth:)
    update!(pro_connect_email: auth.email, state: outcome_for(auth.email))
  end

  def sent_to_support? = state.in?(SUPPORT_STATES)

  def send_code!(browser)
    code = SecureRandom.random_number(1_000_000).to_s.rjust(6, '0')
    update!(code_digest: digest(code), code_sent_at: Time.current)
    UserMailer.pro_connect_migration_code(self, code, browser_description(browser)).deliver_later
  end

  # Counted in one statement: two requests in flight cannot both pass the last attempt.
  def verify_code(code)
    counted = self.class.awaiting_code
      .where(id:, code_sent_at: CODE_VALIDITY.ago.., code_attempts: ...MAX_CODE_ATTEMPTS)
      .update_counters(code_attempts: 1) == 1

    counted && ActiveSupport::SecurityUtils.secure_compare(code_digest, digest(code.to_s.gsub(/\s/, '')))
  end

  private

  def outcome_for(email)
    if email == source_email
      :same_email
    elsif domain(email) != domain(source_email)
      :domain_mismatch
    elsif User.exists?(email:)
      :existing_account
    else
      :awaiting_code
    end
  end

  def domain(email) = email.split('@').last

  def digest(code)
    key = Rails.application.key_generator.generate_key('pro_connect_migration_code')
    OpenSSL::HMAC.hexdigest('SHA256', key, "#{id}:#{code}")
  end

  def browser_description(browser)
    "#{browser.name} #{browser.full_version} (#{browser.platform.name})" if browser.known?
  end
end
