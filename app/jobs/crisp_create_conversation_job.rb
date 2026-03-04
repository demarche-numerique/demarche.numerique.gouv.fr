# frozen_string_literal: true

class CrispCreateConversationJob < ApplicationJob
  include Dry::Monads[:result]

  queue_as :critical # user feedback is critical

  def max_attempts = 15 # ~10h

  class FileNotScannedYetError < StandardError
  end

  retry_on FileNotScannedYetError, wait: :polynomially_longer, attempts: 10

  attr_reader :contact_form
  attr_reader :session_id
  attr_reader :api

  before_perform do |job|
    contact_form = job.arguments.first

    if ignore?(contact_form)
      contact_form.delete
      throw :abort
    end
  end

  def perform(contact_form)
    @contact_form = contact_form

    if contact_form.piece_jointe.attached?
      raise FileNotScannedYetError if contact_form.piece_jointe.virus_scanner.pending?
    end

    @api = Crisp::APIService.new

    @session_id = create_conversation
    send_message
    send_file
    update_metas

    contact_form.delete
  rescue StandardError
    contact_form.delete if executions >= max_attempts

    raise
  end

  private

  def create_conversation
    response = api.create_conversation
    body = handle_api_response(response)
    body.dig(:data, :session_id)
  end

  def send_message
    body = {
      type: "text",
      from: "user",
      origin: "email",
      content: contact_form.text,
      fingerprint: contact_form.id, # must be a number
      timestamp: original_timestamp_ms,
      user: {
        type: "participant",
      },
    }

    response = api.send_message(session_id:, body:)
    handle_api_response(response)
  end

  def send_file
    return unless contact_form.piece_jointe.attached?

    attachment = safe_blob

    return if attachment.blank?

    body = {
      type: "file",
      from: "user",
      origin: "email",
      content: {
        name: attachment.attachable_filename,
        url: attachment.url(expires_in: 1.week),
        type: attachment.content_type,
      },
      fingerprint: attachment.id,
      timestamp: original_timestamp_ms,
      user: {
        type: "participant",
      },
    }

    response = api.send_message(session_id:, body:)
    handle_api_response(response)
  end

  def update_metas
    email, nickname = email_and_nickname

    body = {
      email:,
      nickname:,
      subject: contact_form.subject,
      segments: Set.new(contact_form.user&.crisp_segments) + contact_form.tags,
    }

    body[:data] = { "Dossier" => dossier_link } if contact_form.dossier_id.present?
    body[:ip] = contact_form.user.current_sign_in_ip if contact_form&.user&.current_sign_in_ip.present?
    body[:phone] = contact_form.phone if contact_form.phone.present?
    body[:device] = { system: build_device_system(contact_form.user_agent) } if contact_form.user_agent.present?

    response = api.update_conversation_meta(session_id:, body:)
    handle_api_response(response)
  end

  def handle_api_response(response, &block)
    case response
    in Success(body)
      body
    in Failure(error:)
      fail error
    end
  end

  def email_and_nickname
    email = contact_form.email.presence || contact_form.user.email

    nickname = email.split("@").first.titleize

    [email, nickname]
  end

  def safe_blob
    return if !contact_form.piece_jointe.virus_scanner&.safe?
    return if contact_form.piece_jointe.byte_size.zero?

    contact_form.piece_jointe
  end

  def original_timestamp_ms
    (contact_form.created_at.to_f * 1000).to_i
  end

  def dossier_link
    "[Dossier ##{contact_form.dossier_id}](#{Rails.application.routes.url_helpers.manager_dossier_url(contact_form.dossier_id)})"
  end

  def ignore?(contact_form)
    email = contact_form.email.presence || contact_form.user&.email
    subject = contact_form.subject

    test_patterns = %w[testing ywh yeswehack example burpcollaborator]

    test_patterns.any? do |pattern|
      email.downcase.include?(pattern) || subject.downcase.include?(pattern) || contact_form.user_agent.downcase.include?(pattern)
    end
  end

  def build_device_system(user_agent)
    hash = { useragent: user_agent }

    browser = Browser.new(user_agent)

    hash[:os] = {
      name: browser.platform.name,
      version: browser.platform.version,
    }

    hash[:browser] = {
      name: browser.name,
      major: browser.version,
      version: browser.full_version,
    }

    hash
  end
end
