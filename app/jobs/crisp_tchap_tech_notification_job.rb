# frozen_string_literal: true

class CrispTchapTechNotificationJob < ApplicationJob
  include Dry::Monads[:result]

  CRISP_ROOM_ID = "!nOYpnkgzYvikwhriOQ:agent.dinum.tchap.gouv.fr"
  # keeps the event far below the 65 KB Matrix limit once sent twice and html-escaped
  LAST_MESSAGE_MAX_LENGTH = 2_000

  queue_as :default

  discard_on(Tchap::APIService::RejectedError) { |_job, error| Sentry.capture_exception(error) }

  before_perform do
    throw :abort if inbox_id_dev.blank? || ENV.fetch("TCHAP_BOT_BUGS_TOKEN", nil).blank?
  end

  attr_reader :session_id

  def perform(session_id)
    @session_id = session_id

    result = Crisp::APIService.new.get_conversation(session_id:)

    case result
    in Success(data:)
      return unless data[:inbox_id] == inbox_id_dev

      lines = message_lines(data)

      Tchap::APIService.new.send_notice(
        room_id: ENV["TCHAP_CRISP_ROOM_ID"].presence || CRISP_ROOM_ID,
        txn_id: "crisp-#{job_id}",
        body: lines.map { plain_text(it) }.join("\n"),
        formatted_body: helpers.safe_join(lines.map { html(it) }, helpers.tag.br)
      )
    in Failure(error:)
      fail error
    end
  end

  private

  Link = Data.define(:text, :url)

  def inbox_id_dev = ENV.fetch("CRISP_INBOX_ID_DEV", nil)

  # Each line is an array of parts: a String (user content, escaped in html) or a Link to one of our urls.
  def message_lines(data)
    topic = data[:topic]
    last_message = data[:last_message]&.truncate(LAST_MESSAGE_MAX_LENGTH)
    waiting_since = data[:waiting_since]
    email = data.dig(:meta, :email)
    segments = Array(data.dig(:meta, :segments))
    dossier_id = data.dig(:meta, :data, :Dossier).to_s[/\A\[Dossier #(\d+)\]/, 1]

    lines = [[Link[topic.present? ? "Nouveau ticket dev : #{topic}" : "Nouveau ticket dev", crisp_url]]]

    if last_message.present?
      lines << [""]
      lines.concat(last_message.lines(chomp: true).map { [it] })
      lines << [""]
    end

    manager = []
    if email.present?
      lines << ["Utilisateur : #{email}"]

      user = User.find_by(email:)
      manager << Link["User ##{user.id}", url_helpers.manager_user_url(user)] if user
    end

    manager << Link["Dossier ##{dossier_id}", url_helpers.manager_dossier_url(dossier_id)] if dossier_id

    lines << ["Manager : ", *manager.flat_map { [" • ", it] }.drop(1)] if manager.any?
    lines << ["Segment : #{segments.join(", ")}"] if segments.any?

    if waiting_since.present?
      waiting_at = Time.zone.at(waiting_since / 1000.0)
      lines << ["En attente depuis : #{I18n.l(waiting_at, format: :short_with_time)}"]
    end

    lines
  end

  def plain_text(parts)
    parts.map { it.is_a?(Link) ? "#{it.text} (#{it.url})" : it }.join
  end

  def html(parts)
    helpers.safe_join(parts.map { it.is_a?(Link) ? helpers.link_to(it.text, it.url) : it })
  end

  def crisp_url
    "https://app.crisp.chat/website/#{ENV.fetch("CRISP_WEBSITE_ID")}/inbox/#{URI.encode_uri_component(session_id)}/"
  end

  def helpers = ActionController::Base.helpers
  def url_helpers = Rails.application.routes.url_helpers
end
