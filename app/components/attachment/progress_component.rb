# frozen_string_literal: true

class Attachment::ProgressComponent < ApplicationComponent
  attr_reader :attachment
  attr_reader :ignore_antivirus
  attr_reader :ignore_watermark

  def initialize(attachment:, ignore_antivirus: false, ignore_watermark: false)
    @attachment = attachment
    @ignore_antivirus = ignore_antivirus
    @ignore_watermark = ignore_watermark
  end

  def progress_label
    case
    when !ignore_antivirus && attachment.virus_scanner.pending?
      t(".antivirus_pending")
    when !ignore_watermark && attachment.watermark_pending? && !attachment.watermark_failed?
      t(".watermark_pending")
    end
  end

  def render?
    progress_label.present?
  end
end
