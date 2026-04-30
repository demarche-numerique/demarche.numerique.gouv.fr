# frozen_string_literal: true

class Cron::SendAPIEntrepriseTokenExpirationNoticeJob < Cron::CronJob
  self.schedule_expression = "every day at 08:00"

  WINDOWS = [1.day, 1.week, 1.month]

  def perform
    procedures_with_expiring_token.each do |procedure|
      expires_at = procedure.api_entreprise_token.expires_at
      current_window = matching_window(expires_at)
      next if current_window.nil?

      last_sent_at = procedure.api_entreprise_token_expiration_notice_sent_at
      next if last_sent_at.present? && matching_window(expires_at, reference_time: last_sent_at) == current_window

      procedure.administrateurs.includes(:user).find_each do |admin|
        AdministrateurMailer.api_entreprise_token_expiration(admin, procedure).deliver_later
      end

      procedure.update!(api_entreprise_token_expiration_notice_sent_at: Time.current)
    end
  end

  private

  def procedures_with_expiring_token
    Procedure.kept
      .where.not(api_entreprise_token: [nil, ''])
      .filter { it.api_entreprise_token.expired_or_expires_soon? }
  end

  def matching_window(expires_at, reference_time: Time.current)
    WINDOWS.find { |window| expires_at <= reference_time + window }
  end
end
