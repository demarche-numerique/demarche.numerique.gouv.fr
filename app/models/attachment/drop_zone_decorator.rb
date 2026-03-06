# frozen_string_literal: true

# Decorator that provides data-attributes to turn any element into a drop zone.
#
# Modes:
# - integrated: input is child of drop zone (default for file field drop zones)
# - remote: input is elsewhere in DOM (for textarea in messaging)
#
# Usage:
#   decorator = Attachment::DropZoneDecorator.new(input_selector: '#file-123', mode: :remote)
#   <%= f.text_area :body, data: decorator.data_attributes %>
class Attachment::DropZoneDecorator
  attr_reader :input_selector, :mode

  def initialize(input_selector: nil, mode: :integrated)
    @input_selector = input_selector
    @mode = mode

    validate!
  end

  # Data attributes for Stimulus controller
  def data_attributes
    attrs = {
      controller: 'drop-target',
      action: [
        'dragover->drop-target#onDragOver',
        'dragleave->drop-target#onDragLeave',
        'drop->drop-target#onDrop',
      ].join(' '),
    }

    # For remote mode, specify where to find the input
    if @mode == :remote && @input_selector
      attrs[:'drop-target-input-selector-value'] = @input_selector
    end

    attrs
  end

  # CSS class for drop zone styling
  def css_class
    'attachment-drop-zone'
  end

  # Helper to merge with existing attributes
  #
  # Example:
  #   decorator.merge_into({ class: 'fr-input', data: { foo: 'bar' } })
  #   # => { class: 'fr-input attachment-drop-zone', data: { foo: 'bar', controller: 'drop-target', ... } }
  def merge_into(attributes = {})
    {
      class: [attributes[:class], css_class].compact.join(' '),
      data: (attributes[:data] || {}).merge(data_attributes),
    }
  end

  private

  def validate!
    unless [:integrated, :remote].include?(@mode)
      raise ArgumentError, "Invalid mode: #{@mode}, must be :integrated or :remote"
    end

    if @mode == :remote && @input_selector.nil?
      raise ArgumentError, "input_selector is required for remote mode"
    end
  end
end
