# frozen_string_literal: true

class CreateRepresentationsJob < ApplicationJob
  include Skylight::Helpers
  include UnreadableVipsSourceConcern

  queue_as :ultra_low

  discard_on ActiveJob::DeserializationError
  discard_on ActiveRecord::RecordNotFound
  discard_on ActiveStorage::FileNotFoundError
  discard_on ActiveRecord::InvalidForeignKey

  retry_on "Vips::Error", attempts: 3 # not as const because vips is loaded at runtime
  retry_on SandboxedCommand::WrapperFailed, attempts: 3 # should be rare

  rescue_from ActiveStorage::PreviewError do |exception|
    if executions < 3
      retry_job wait: 5.minutes, error: exception
    end
  end

  instrument_method
  def perform(blob)
    return if blob.nil?

    blob.attachments.find_each do |att|
      next if !att.representable?

      att.representation(resize_to_limit: [400, 400]).processed

      if att.blob.content_type.in?(RARE_IMAGE_TYPES)
        att.variant(resize_to_limit: [2000, 2000]).processed
      end

      if att.record.class == ActionText::RichText
        att.variant(resize_to_limit: [1024, 768]).processed
      end
    end
  rescue Vips::Error => error
    # The blob is the same file for every attachment, so a source vips cannot decode
    # yields no representation for any of them — and never will. Give up quietly rather
    # than retrying three times and reporting.
    raise if !unreadable_vips_source?(error)
  end
end
