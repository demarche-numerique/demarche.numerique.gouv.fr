# frozen_string_literal: true

class CrispMattermostTechNotificationJob < ApplicationJob
  include Dry::Monads[:result]

  queue_as :default

  before_perform do
    throw :abort if inbox_id_dev.blank? || webhook_url.blank?
  end

  attr_reader :session_id

  def perform(session_id)
    @session_id = session_id

    result = Crisp::APIService.new.get_conversation(session_id:)

    case result
    in Success(data:)
      return unless data[:inbox_id] == inbox_id_dev

      message = build_mattermost_message(data)

      send_mattermost_notification(message)
    in Failure(error:)
      fail error
    end
  end

  private

  def webhook_url = ENV.fetch("SUPPORT_WEBHOOK_URL", nil)
  def inbox_id_dev = ENV.fetch("CRISP_INBOX_ID_DEV", nil)

  def send_mattermost_notification(message)
    result = API::Client.new.call(url: webhook_url, json: { "text": message }, method: :post)
    case result
    in Success(_)
      # NOOP
    in Failure(error:)
      fail error
    end
  end

  def build_mattermost_message(data)
    topic = data[:topic]
    last_message = data[:last_message]
    waiting_since = data[:waiting_since]
    email = data.dig(:meta, :email)
    segments = data.dig(:meta, :segments)
    dossier_link = data.dig(:meta, :data, :Dossier) # from metadata already set

    message_lines = ["---"] # visual separation from previous message

    message_lines << if topic.present?
      ["**Nouveau ticket dev : [#{topic}](#{crisp_url})**"]
    else
      ["**[Nouveau ticket dev](#{crisp_url})**"]
    end

    if last_message.present?
      message_lines << ""
      message_lines << last_message
    end

    manager = []
    if email.present?
      message_lines << "**Utilisateur :** #{email}"

      user = User.find_by(email:)
      user_link = "[User ##{user.id}](#{Rails.application.routes.url_helpers.manager_user_url(user, host:)})" if user
      manager << user_link
    end

    manager << dossier_link if dossier_link

    if manager.any?
      message_lines << "**Manager :** #{manager.compact.join(" • ")}"
    end

    if segments.any?
      message_lines << "**Segment :** #{segments.join(", ")}"
    end

    if waiting_since.present?
      waiting_at = Time.zone.at(waiting_since / 1000.0)
      message_lines << "**En attente depuis :** #{I18n.l(waiting_at, format: :short_with_time)}"
    end

    message_lines.join("\n")
  end

  def crisp_url
    "https://app.crisp.chat/website/#{ENV.fetch("CRISP_WEBSITE_ID")}/inbox/#{session_id}/"
  end

  def host = ENV["APP_HOST"]
end
