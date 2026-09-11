# frozen_string_literal: true

class Attachment::ShowComponent < ApplicationComponent
  def initialize(attachment:, new_tab: false, truncate: false)
    @attachment = attachment
    @new_tab = new_tab
    @truncate = truncate
  end

  attr_reader :attachment, :new_tab, :truncate

  def should_display_link?
    (attachment.virus_scanner.safe? || !attachment.virus_scanner.started?) && !attachment.watermark_pending?
  end

  def error_message
    case
    when attachment.virus_scanner.infected?
      t(".errors.virus_infected")
    when attachment.virus_scanner.corrupt?
      t(".errors.corrupted_file")
    when attachment.watermark_failed?
      t(".errors.watermark_failed")
    end
  end

  def error?
    attachment.virus_scanner_error? || attachment.watermark_failed?
  end
end
