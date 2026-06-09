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

  attr_reader :context, :max, :drop_zone, :attachments, :current_count, :hidden, :input_id

  delegate :champ, :form_object_name, :view_as, :user_can_destroy?, :aria_labelledby, :attached_file,
           to: :context

  def initialize(context:, drop_zone:, max: nil, attachments: nil, hidden: false, id: nil)
    @context = context
    @drop_zone = drop_zone
    @hidden = hidden
    @input_id = id

    # Get attachments
    @attachments = if attachments
      Array(attachments).compact
    elsif attached_file.is_a?(ActiveStorage::Attached::Many)
      attached_file.attachments.to_a
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

  def progress_container_id
    champ.present? ? "attachment-progress-#{champ.public_id}" : "attachment-progress-generic"
  end

  def describedby_hint_id
    return nil if champ.nil?
    "#{champ.focusable_input_id}-hint"
  end

  def drop_zone_labelledby_id
    return nil if champ.nil?
    helpers.input_label_id(champ)
  end

  def drop_zone_describedby_ids
    return nil if champ.nil?

    ids = [describedby_hint_id]
    ids << champ.describedby_id if champ.description.present?
    ids.compact.join(' ').presence
  end

  def error_wrapper_id
    champ.present? ? "attachment-error-#{champ.public_id}" : "attachment-error-generic"
  end

  def hints_component
    Attachment::HintsComponent.new(
      champ:,
      attached_file:,
      show_identity_hint: champ&.titre_identite?,
      html_id: describedby_hint_id,
      max: @max
    )
  end

  def file_input_component
    Attachment::FileInputComponent.new(
      context:,
      max: @max,
      current_count: @current_count,
      hidden: @hidden,
      id: @input_id,
      keyboard_focusable: @drop_zone != :integrated
    )
  end

  def drop_zone_decorator
    return nil if @drop_zone == :none

    @drop_zone_decorator ||= Attachment::DropZoneDecorator.new(mode: :integrated)
  end

  def field_name
    file_input_component.field_name_or_default
  end

  def attachment_rerender_after_validation_error?
    attached_file.record.new_record? && @attachments.any?
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
