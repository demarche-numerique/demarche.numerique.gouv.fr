# frozen_string_literal: true

class FranceConnectInformation < ApplicationRecord
  MERGE_VALIDITY = 15.minutes
  CONFIRMATION_EMAIL_VALIDITY = 2.days

  belongs_to :user, optional: true

  validates :france_connect_particulier_id, presence: true, allow_blank: false, allow_nil: false

  def safely_associate_user!(email)
    begin
      user = User.create!(
        email: email.downcase,
        password: Devise.friendly_token[0, 20],
        confirmed_at: Time.zone.now
      )

      update_attribute('user_id', user.id)
    rescue ActiveRecord::RecordNotUnique
      # ignore this exception because we check before if user is nil.
      # exception can be raised in race conditions, when FranceConnect calls callback 2 times.
      # At the 2nd call, user is nil but exception is raised at the creation of the user
      # because the first call has already created a user
    end

    clean_tokens_and_requested_email
    save!
  end

  def safely_update_user(user:)
    self.user = user
    clean_tokens_and_requested_email
    save!
  end

  def send_custom_confirmation_instructions
    token = SecureRandom.hex(10)
    user.update!(confirmation_token: token, confirmation_sent_at: Time.zone.now)
    UserMailer.custom_confirmation_instructions(user, token).deliver_later
  end

  def create_merge_token!
    merge_token = SecureRandom.uuid
    update(merge_token:, merge_token_created_at: Time.zone.now)

    merge_token
  end

  def create_email_merge_token!
    email_merge_token = SecureRandom.uuid
    update(email_merge_token:, email_merge_token_created_at: Time.zone.now)

    email_merge_token
  end

  def valid_for_merge?
    (MERGE_VALIDITY.ago < merge_token_created_at) && user_id.nil?
  end

  def valid_for_email_merge?
    (MERGE_VALIDITY.ago < email_merge_token_created_at) && user_id.nil?
  end

  def delete_email_merge_token!
    update(email_merge_token: nil, email_merge_token_created_at: nil)
  end

  def clean_tokens_and_requested_email
    self.merge_token = nil
    self.merge_token_created_at = nil
    self.email_merge_token = nil
    self.email_merge_token_created_at = nil
    self.requested_email = nil
  end

  def complete?(with_gender:)
    given_name.present? && family_name.present? && (!with_gender || gender.present?)
  end

  def full_name
    [given_name, family_name].compact.join(" ")
  end
end
