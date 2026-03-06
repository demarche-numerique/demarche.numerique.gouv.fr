# frozen_string_literal: true

# Unified file upload field component.
# Replaces UniqueComponent and MultipleComponent with a single, flexible component.
#
# Handles both:
# - Single file (max=1): shows either uploader OR file (replacement mode)
# - Multiple files (max>1): shows uploader AND files list (accumulation mode)
#
# Parameters automatically deduced when possible:
# - as_multiple: from has_one_attached vs has_many_attached
# - max: 1 for has_one, 10 for has_many (can be overridden)
# - drop_zone: ALWAYS explicit (:none, :integrated)
#
# Usage:
#   # Simple case (all defaults deduced)
#   = render Attachment::FileFieldComponent.new(\
#       context: Attachment::Context.new(champ:),\
#       drop_zone: :integrated\
#     )
#
#   # Override max for RIB (has_many but max=1)
#   = render Attachment::FileFieldComponent.new(\
#       context: Attachment::Context.new(champ:),\
#       max: 1,\
#       drop_zone: :integrated\
#     )
class Attachment::FileFieldComponent < ApplicationComponent
  DEFAULT_MAX_ATTACHMENTS = 10

  renders_one :template

  attr_reader :context, :max, :drop_zone, :attachments, :current_count

  delegate :champ, :form_object_name, :view_as, :user_can_destroy?, :aria_labelledby, :attached_file,
           to: :context

  def initialize(context:, drop_zone:, max: nil, attachments: nil)
    @context = context
    @drop_zone = drop_zone

    # Get attachments
    @attachments = if attachments
      Array(attachments).compact
    elsif attached_file.is_a?(ActiveStorage::Attached::Many)
      attached_file.attachments
    elsif attached_file.is_a?(ActiveStorage::Attached::One) && attached_file.attached?
      [attached_file.attachment]
    else
      []
    end

    @current_count = @attachments.size

    # Deduce max if not specified
    @max = max || infer_max

    validate!
  end

  # Should we show the uploader input?
  def show_uploader?
    @current_count < @max
  end

  # Should we show files as a list? (vs single replacement)
  def show_as_list?
    @max > 1
  end

  # Should we show hints?
  def show_hint?
    champ.present?
  end

  def empty_component_id
    champ.present? ? "attachment-empty-#{champ.public_id}" : "attachment-empty-generic"
  end

  def describedby_hint_id
    return nil if champ.nil?
    "#{champ.focusable_input_id}-hint"
  end

  def hints_component
    Attachment::HintsComponent.new(
      champ:,
      attached_file:,
      show_identity_hint: champ&.titre_identite_nature?,
      html_id: describedby_hint_id
    )
  end

  def file_input_component
    Attachment::FileInputComponent.new(
      context:,
      max: @max,
      current_count: @current_count
    )
  end

  def drop_zone_decorator
    return nil if @drop_zone == :none

    @drop_zone_decorator ||= Attachment::DropZoneDecorator.new(mode: :integrated)
  end

  private

  def infer_max
    if attached_file.is_a?(ActiveStorage::Attached::One)
      1
    else
      DEFAULT_MAX_ATTACHMENTS
    end
  end

  def validate!
    unless [:none, :integrated].include?(@drop_zone)
      raise ArgumentError, "Invalid drop_zone: #{@drop_zone}, must be :none or :integrated"
    end
  end
end
