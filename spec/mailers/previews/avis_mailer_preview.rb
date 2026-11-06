# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/avis_mailer
class AvisMailerPreview < ActionMailer::Preview
  def avis_invitation_and_confirm_email_with_unconfirmed_user
    avis_with_unconfirmed_user = Avis.joins(expert: :user).where(users: { last_sign_in_at: nil }).first
    raise if avis_with_unconfirmed_user.nil?

    AvisMailer.avis_invitation_and_confirm_email(
      avis_with_unconfirmed_user.expert.user,
      avis_with_unconfirmed_user.expert.user.confirmation_token,
      avis_with_unconfirmed_user
    )
  end

  def avis_invitation_and_confirm_email_with_confirmed_and_unverified_user_email
    avis_with_unverified_user = Avis.joins(expert: :user).where.not(users: { last_sign_in_at: nil }).where(users: { email_verified_at: nil }).first
    raise if avis_with_unverified_user.nil?

    AvisMailer.avis_invitation_and_confirm_email(
      avis_with_unverified_user.expert.user,
      avis_with_unverified_user.expert.user.confirmation_token,
      avis_with_unverified_user
    )
  end

  def avis_invitation_and_confirm_email_with_confirmed_and_verified_user_email
    avis_with_verified_user = Avis.joins(expert: :user).where.not(users: { last_sign_in_at: nil }).where.not(users: { email_verified_at: nil }).first
    raise if avis_with_verified_user.nil?

    AvisMailer.avis_invitation_and_confirm_email(
      avis_with_verified_user.expert.user,
      avis_with_verified_user.expert.user.confirmation_token,
      avis_with_verified_user
    )
  end

  def notify_new_avis_to_expert
    AvisMailer.notify_new_avis_to_expert(Avis.not_revoked.first!)
  end
end
