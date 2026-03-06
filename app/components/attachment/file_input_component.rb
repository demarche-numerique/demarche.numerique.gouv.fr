# frozen_string_literal: true

# Generates a file input element (<input type="file">).
# - Automatically deduces 'multiple' attribute from attached_file type (has_one vs has_many)
# - Can be visible or hidden (for remote drop zones)
# - Used standalone or wrapped by DropZone components
class Attachment::FileInputComponent < ApplicationComponent
  attr_reader :context, :max, :current_count, :hidden

  delegate :champ, :direct_upload, :aria_labelledby,
           :parent_hint_id, :form_object_name, :attached_file, to: :context

  def initialize(context:, max: nil, current_count: 0, hidden: false, id: nil)
    @context = context
    @max = max
    @current_count = current_count
    @hidden = hidden
    @input_id = id
  end

  # Automatically deduce from ActiveStorage type
  def as_multiple?
    attached_file.is_a?(ActiveStorage::Attached::Many)
  end

  def attachment_input_class
    "attachment-input-#{attachment_id}"
  end

  def attachment_id
    @attachment_id ||= SecureRandom.uuid
  end

  def validation
    @validation ||= Attachment::Validation.new(attached_file:)
  end

  def file_field_options
    options = {
      class: class_names(
        "fr-upload attachment-input": true,
        "#{attachment_input_class}": true,
        "sr-only": @hidden
      ),
      direct_upload:,
      id: final_input_id,
      data: {
        auto_attach_url:,
        turbo_force: :server,
        'enable-submit-if-uploaded-target': 'input',
      }.merge(validation.max_file_size.present? ? { max_file_size: validation.max_file_size } : {})
        .merge(as_multiple? && @max ? { max: @max } : {}),
    }

    describedby = []
    describedby << champ.describedby_id if champ&.description.present?
    describedby << parent_hint_id if parent_hint_id.present?
    describedby << champ.error_id(:value) if champ&.errors&.has_key?(:value)

    options[:aria] = { describedby: describedby.join(' '), labelledby: aria_labelledby }

    accept = validation.accept_attribute
    options.merge!(accept.present? ? { accept: } : {})
    options[:multiple] = true if as_multiple?
    options[:disabled] = true if @max && @current_count >= @max

    options
  end

  def auto_attach_url
    return context.auto_attach_url if context.auto_attach_url.present?
    return helpers.auto_attach_url(champ) if champ.present?

    nil
  end

  def field_name_or_default
    field_name = form_object_name || ActiveModel::Naming.param_key(attached_file.record)
    base_name = "#{field_name}[#{attribute_name}]"
    # Rails convention: multiple file inputs need [] suffix to submit as array
    as_multiple? ? "#{base_name}[]" : base_name
  end

  def attribute_name
    attached_file.name
  end

  def final_input_id
    @input_id || (champ.present? ? champ.focusable_input_id : dom_id(attached_file.record, attribute_name))
  end

  # Alias for backward compatibility
  alias input_id final_input_id
end
