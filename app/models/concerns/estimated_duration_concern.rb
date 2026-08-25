# frozen_string_literal: true

module EstimatedDurationConcern
  extend ActiveSupport::Concern

  FILL_DURATION_SHORT  = 10.seconds
  FILL_DURATION_MEDIUM = 1.minute
  FILL_DURATION_LONG   = 3.minutes
  READ_WORDS_PER_SECOND = 140.0 / 60 # 140 words per minute

  # Default estimated duration to fill the champ in a form, in seconds.
  # May be overridden by subclasses.
  def estimated_fill_duration(revision)
    if fillable?
      FILL_DURATION_SHORT
    else
      0.seconds
    end
  end

  def estimated_read_duration
    return 0.seconds if description.blank?

    sanitizer = Rails::Html::Sanitizer.full_sanitizer.new
    content = sanitizer.sanitize(description)

    words = content.split(/\s+/).size

    (words / READ_WORDS_PER_SECOND).round.seconds
  end
end
