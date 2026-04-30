# frozen_string_literal: true

# Displays an attachment: filename/download link, antivirus status, delete button.
# Handles both persisted and unpersisted attachments (e.g. after validation error).
# Read-only display component (no file input).
class Attachment::AttachmentRowComponent < ApplicationComponent
  attr_reader :attachment, :context

  delegate :champ, :auto_attach_url, :direct_upload, :view_as, :user_can_destroy?,
           to: :context

  def initialize(attachment:, context:, field_name: nil)
    @attachment = attachment
    @context = context
    @field_name = field_name
  end

  def attachment_path(**args)
    helpers.attachment_path attachment.id, args.merge(signed_id: attachment.blob.signed_id)
  end

  def destroy_attachment_path
    if champ.present?
      attachment_path
    else
      attachment_path(auto_attach_url:, view_as:, direct_upload:)
    end
  end

  def remove_button_options
    {
      role: 'button',
      data: { turbo: "true", turbo_method: :delete },
    }
  end

  def downloadable?
    return false unless context.downloadable?

    viewable?
  end

  def viewable?
    return false if attachment.virus_scanner_error?
    return false if attachment.watermark_pending?

    true
  end

  def error_message
    case
    when attachment.virus_scanner.infected?
      t(".errors.virus_infected")
    when attachment.virus_scanner.corrupt?
      t(".errors.corrupted_file")
    end
  end
end
