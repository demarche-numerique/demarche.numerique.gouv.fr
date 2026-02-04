# frozen_string_literal: true

class ImageProcessorJob < ApplicationJob
  queue_as do
    blob = self.arguments.first
    maybe_champ = blob&.attachments&.first&.record

    if rib?(maybe_champ)
      :default # UI is waiting
    else
      :low # thumbnails and watermarks. Execution depends of virus scanner which is more urgent
    end
  end

  class FileNotScannedYetError < StandardError
  end

  # If by the time the job runs the blob has been deleted, ignore the error
  discard_on ActiveRecord::RecordNotFound
  # If the file is deleted during the scan, ignore the error
  discard_on ActiveStorage::FileNotFoundError
  discard_on ActiveRecord::InvalidForeignKey

  # If imagemagick can't process the image due to policy.xml or the file itself, ignore the error
  KNOWN_ERRORS = [
    'improper image header',
    'width or height exceeds limit',
    'attempt to perform an operation not allowed by the security policy',
    'no decode delegate for this image format',
  ]
  # If the file is not analyzed or scanned for viruses yet, retry later
  # (to avoid modifying the file while it is being scanned).
  retry_on FileNotScannedYetError, wait: :polynomially_longer, attempts: 10

  # Usually invalid image or ImageMagick decoder blocked for this format
  retry_on MiniMagick::Invalid, attempts: 3
  retry_on MiniMagick::Error, attempts: 3

  rescue_from ActiveStorage::PreviewError do |exception|
    retry_or_discard(exception)
  end

  def perform(blob)
    return if blob.nil?
    raise FileNotScannedYetError if blob.virus_scanner.pending?
    return if ActiveStorage::Attachment.find_by(blob_id: blob.id)&.record_type == "ActiveStorage::VariantRecord"

    add_ocr_data(blob)
    auto_rotate(blob) if ["image/jpeg", "image/jpg"].include?(blob.content_type)
    uninterlace(blob) if blob.content_type == "image/png"
    create_representations(blob) if blob.representation_required? && mime_type_authorized_by_policy?(blob)
    add_watermark(blob) if blob.watermark_pending?
  rescue MiniMagick::Error => e
    if KNOWN_ERRORS.any? { e.message.match?(it) }
      Rails.logger.info "ImageProcessorJob raising known error: #{e.message}"
    else
      raise e
    end
  end

  private

  def mime_type_authorized_by_policy?(blob)
    blob.content_type.in?(AUTHORIZED_CONTENT_TYPES_IN_POLICY_XML)
  end

  def auto_rotate(blob)
    blob.open do |file|
      Tempfile.create(["rotated", File.extname(file)]) do |output|
        processed = AutoRotateService.new.process(file, output)
        return if processed.blank?

        blob.upload(processed) # also update checksum & byte_size accordingly
        blob.save!
      end
    end
  end

  def uninterlace(blob)
    blob.open do |file|
      processed = UninterlaceService.new.process(file)
      return if processed.blank?

      blob.upload(processed)
      blob.save!
    end
  end

  def create_representations(blob)
    blob.attachments.each do |attachment|
      next unless attachment&.representable?
      attachment.representation(resize_to_limit: [400, 400]).processed
      if attachment.blob.content_type.in?(RARE_IMAGE_TYPES)
        attachment.variant(resize_to_limit: [2000, 2000]).processed
      end
      if attachment.record.class == ActionText::RichText
        attachment.variant(resize_to_limit: [1024, 768]).processed
      end
    end
  end

  def add_watermark(blob)
    return if blob.watermark_done?

    blob.open do |file|
      Tempfile.create(["watermarked", File.extname(file)]) do |output|
        processed = WatermarkService.new.process(file, output)
        return if processed.blank?

        blob.upload(processed) # also update checksum & byte_size accordingly
        blob.watermarked_at = Time.current
        blob.save!
      end
    end
  end

  def add_ocr_data(blob)
    champ = blob&.attachments&.first&.record
    return if !rib?(champ)
    return if !champ.may_fetch? # a previous blob may have already been analyzed

    champ.fetch!
  end

  def rib?(champ)
    return false if !champ.is_a?(Champs::PieceJustificativeChamp)

    champ.RIB?
  end

  def retry_or_discard(exception)
    if executions < 3
      retry_job wait: 5.minutes, error: exception
    end
  end
end
