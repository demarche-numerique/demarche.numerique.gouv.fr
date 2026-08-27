# frozen_string_literal: true

class BlobProcessorJob < ApplicationJob
  include Skylight::Helpers
  include UnreadableVipsSourceConcern

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
  require 'fog/openstack/auth/token'
  discard_on Fog::OpenStack::Auth::Token::URLError

  retry_on(ActiveStorage::IntegrityError, attempts: 5, wait: 5.seconds) do |job, _error|
    blob = job.arguments.first
    blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::INTEGRITY_ERROR, virus_scanned_at: Time.current)
  end

  retry_on "Vips::Error", attempts: 3 # not as const because vips is loaded at runtime
  retry_on WatermarkService::Error, attempts: 3

  # retry if something wrong with namespace but it should not happens
  retry_on SandboxedCommand::WrapperFailed, attempts: 3

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
          apply_mutations(tempfile.path)
        end
      end
    end

    return mark_processed if !blob.virus_scanner.safe?
    return mark_processed if attachment.nil?

    # Phase 2: OCR (external API call)
    add_ocr_data

    # Phase 3: Representations — delegated to ultra_low queue
    CreateRepresentationsJob.perform_later(blob) if blob.representation_required?

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
  def apply_mutations(path)
    header = header(path) if jpeg? || png_embeddable_in_pdf?
    autorotate_needed = jpeg? && autorotate_needed?(header)
    uninterlace_needed = png_embeddable_in_pdf? && interlaced?(header)

    watermark_needed = blob.watermark_pending?
    mutations_needed = autorotate_needed || uninterlace_needed || watermark_needed

    return if !mutations_needed

    decode(path, autorotate: autorotate_needed) do |image|
      image = WatermarkService.new.apply(image, format: blob.content_type) if watermark_needed

      write_opts = uninterlace_needed ? { interlace: false } : {}

      Tempfile.create(["processed", File.extname(path)]) do |output|
        image.write_to_file(output.path, **write_opts)
        blob.upload(output)
      end
    end

    blob.watermarked_at = Time.current if watermark_needed
    blob.save!
  rescue Vips::Error => error
    # A source vips cannot decode is not a transient failure, so skip the mutations and
    # let the rest of the job run (the blob still gets marked processed) instead of
    # burning three retries.
    raise if !unreadable_vips_source?(error)

    Sentry.capture_exception(error) if blob.watermark_pending?
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

  def header(path)
    return SandboxedVips.header(path) if SandboxedCommand::ENABLED

    Vips::Image.new_from_file(path).then { |image| image.get_fields.index_with { image.get(it) } }
  rescue Vips::Error
    {}
  end

  def autorotate_needed?(header) = header.include?("orientation") && header["orientation"] != 1

  def interlaced?(header) = header.include?("interlaced") && header["interlaced"] != 0

  def decode(path, autorotate:, &)
    load_opts = { access: :sequential }
    load_opts[:autorotate] = true if autorotate

    return SandboxedVips.disarm(path, **load_opts, &) if SandboxedCommand::ENABLED

    yield Vips::Image.new_from_file(path, **load_opts)
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
