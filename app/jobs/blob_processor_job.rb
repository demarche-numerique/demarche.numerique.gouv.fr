# frozen_string_literal: true

class BlobProcessorJob < ApplicationJob
  include Skylight::Helpers

  queue_as do
    blob = self.arguments.first
    attachment = blob&.attachments&.includes(:record)&.first

    if ocr_compatible?(attachment&.record)
      :default # UI is waiting for OCR result
    else
      :low # thumbnails and watermarks can wait
    end
  end

  discard_on ActiveRecord::RecordNotFound
  discard_on ActiveStorage::FileNotFoundError
  discard_on ActiveRecord::InvalidForeignKey

  retry_on(ActiveStorage::IntegrityError, attempts: 5, wait: 5.seconds) do |job, _error|
    blob = job.arguments.first
    blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::INTEGRITY_ERROR, virus_scanned_at: Time.current)
  end

  retry_on "Vips::Error", attempts: 3 # not as const because vips is loaded at runtime
  retry_on WatermarkService::Error, attempts: 3

  rescue_from ActiveStorage::PreviewError do |exception|
    retry_or_discard(exception)
  end

  attr_reader :blob, :attachment

  def perform(blob)
    require "vips"

    @blob = blob
    return if blob.nil?
    # Idempotency guard: during deployment, old VirusScannerJob/ImageProcessorJob may
    # overlap with new BlobProcessorJob for the same blob. Skip if already processed.
    return if blob.metadata["processed"]

    @attachment = blob.attachments.includes(:record).first

    processable = blob.content_type.in?(PROCESSABLE_TYPES)

    # Phase 1: Virus scan + image mutations in a single blob.open to minimize downloads
    Skylight.instrument(title: "blob.open (download)", category: "app.blob_processor") do
      blob.open do |tempfile|
        scan_virus(tempfile) if !blob.virus_scanner.done?

        if attachment && blob.virus_scanner.safe? && processable && needs_mutations?
          apply_mutations(tempfile)
        end
      end
    end

    return mark_processed if !blob.virus_scanner.safe?
    return mark_processed if attachment.nil?

    # Phase 2: OCR (external API call)
    add_ocr_data

    # Phase 3: Representations (ActiveStorage manages its own downloads)
    create_representations if blob.representation_required?

    mark_processed
  end

  private

  instrument_method
  def scan_virus(tempfile)
    if ClamavService.safe_file?(tempfile.path)
      blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::SAFE, virus_scanned_at: Time.current)
    else
      blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::INFECTED, virus_scanned_at: Time.current)
    end
  end

  instrument_method
  def apply_mutations(tempfile)
    autorotate_needed = jpeg? && autorotate_needed?(tempfile)
    uninterlace_needed = png_embeddable_in_pdf? && interlaced?(tempfile)
    watermark_needed = blob.watermark_pending?
    mutations_needed = autorotate_needed || uninterlace_needed || watermark_needed

    return if !mutations_needed

    load_opts = { access: :sequential }
    load_opts[:autorotate] = true if autorotate_needed

    image = Vips::Image.new_from_file(tempfile.to_path, **load_opts)
    image = WatermarkService.new.apply(image, format: blob.content_type) if watermark_needed

    write_opts = uninterlace_needed ? { interlace: false } : {}

    Tempfile.create(["processed", File.extname(tempfile.path)]) do |output|
      image.write_to_file(output.path, **write_opts)
      blob.upload(output)
    end

    blob.watermarked_at = Time.current if watermark_needed
    blob.save!
  end

  def needs_mutations?
    jpeg? || png_embeddable_in_pdf? || blob.watermark_pending?
  end

  def jpeg?
    blob.content_type.in?(["image/jpeg", "image/jpg"])
  end

  def png_embeddable_in_pdf?
    blob.content_type == "image/png" && embeddable_in_pdf?
  end

  def embeddable_in_pdf?
    attachment.name.in?(%w[logo signature]) &&
      attachment.record_type.in?(%w[AttestationTemplate GroupeInstructeur])
  end

  def autorotate_needed?(tempfile)
    image = Vips::Image.new_from_file(tempfile.to_path)
    image.get_fields.include?("orientation") && image.get("orientation") != 1
  rescue Vips::Error # unreadable metadata should not abort processing: skip the mutation instead
    false
  end

  def interlaced?(tempfile)
    image = Vips::Image.new_from_file(tempfile.to_path)
    image.get_fields.include?("interlaced") && image.get("interlaced") != 0
  rescue Vips::Error # unreadable metadata should not abort processing: skip the mutation instead
    false
  end

  instrument_method
  def create_representations
    blob.attachments.each do |att|
      next if !att.representable?
      att.representation(resize_to_limit: [400, 400]).processed
      if att.blob.content_type.in?(RARE_IMAGE_TYPES)
        att.variant(resize_to_limit: [2000, 2000]).processed
      end
      if att.record.class == ActionText::RichText
        att.variant(resize_to_limit: [1024, 768]).processed
      end
    end
  end

  instrument_method
  def add_ocr_data
    champ = attachment.record
    return if !ocr_compatible?(champ)
    return if !champ.may_fetch?

    champ.fetch!
  end

  def ocr_compatible?(maybe_champ)
    return false if !maybe_champ.is_a?(Champs::PieceJustificativeChamp)

    maybe_champ.ocr_compatible?
  end

  def mark_processed
    if !blob.metadata["processed"]
      blob.metadata["processed"] = true
      blob.save!
    end
  end

  def retry_or_discard(exception)
    if executions < 3
      retry_job wait: 5.minutes, error: exception
    end
  end
end
