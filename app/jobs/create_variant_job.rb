# frozen_string_literal: true

class CreateVariantJob < ApplicationJob
  # Use a dedicated queue for backfill operations, should be configured with lower priority than :low
  queue_as :backfill

  discard_on ActiveRecord::RecordNotFound
  discard_on ActiveStorage::FileNotFoundError
  discard_on ActiveRecord::InvalidForeignKey

  retry_on MiniMagick::Invalid, attempts: 3
  retry_on MiniMagick::Error, attempts: 3

  rescue_from ActiveStorage::PreviewError do
    retry_or_discard
  end

  def perform(attachment_id, file_type: nil)
    attachment = ActiveStorage::Attachment.find(attachment_id)
    return if !attachment.representable? || !attachment.representation_required?
    return if skip_attachment?(attachment, file_type)

    if attachment.variable?
      attachment.variant(resize_to_limit: [400, 400]).processed if attachment.variant(resize_to_limit: [400, 400]).key.nil?
      if attachment.blob.content_type.in?(RARE_IMAGE_TYPES) && attachment.variant(resize_to_limit: [2000, 2000]).key.nil?
        attachment.variant(resize_to_limit: [2000, 2000]).processed
      end
    elsif attachment.previewable?
      attachment.representation(resize_to_limit: [400, 400]).processed
    end
  end

  private

  def skip_attachment?(attachment, file_type)
    return false if file_type.blank?

    content_type = attachment.blob.content_type
    case file_type
    when 'image'
      !content_type.in?(AUTHORIZED_IMAGE_TYPES)
    when 'pdf'
      !content_type.in?(AUTHORIZED_PDF_TYPES)
    else
      false
    end
  end

  def retry_or_discard
    if executions < 3
      retry_job wait: 5.minutes
    end
  end
end
