# frozen_string_literal: true

class Attachment::Validation
  EXTENSIONS_ORDER = ['jpeg', 'png', 'pdf', 'zip'].freeze

  attr_reader :attached_file

  def initialize(attached_file:)
    @attached_file = attached_file
  end

  def record
    @record ||= attached_file.record
  end

  def champ
    @champ ||= record if record.is_a?(ChampData)
  end

  def max_file_size
    return champ.max_file_size_bytes if champ.present?
    return nil if file_size_validator.nil?
    file_size_validator.options[:less_than]
  end

  def accept_attribute
    content_types = champ.presence&.allowed_content_types

    return content_types_with_extensions(content_types) if content_types.present?
    accept_from_attached_type_de_champ || (has_content_type_validator? ? accept_content_type : nil)
  end

  def allowed_extensions
    @allowed_extensions ||= begin
      if champ.present?
        extensions = champ.allowed_content_types.filter_map { |ct| MiniMime.lookup_by_content_type(ct)&.extension }.uniq
        sorted = extensions.sort_by { |e| EXTENSIONS_ORDER.index(e) || 999 }
        return sorted.size > 5 ? (sorted.first(5) + ['…']) : sorted
      end

      raw = has_content_type_validator? ? content_type_validator_list : []

      extensions = raw.filter_map { |ct| MiniMime.lookup_by_content_type(ct)&.extension }.uniq
      sorted = extensions.sort_by { |e| EXTENSIONS_ORDER.index(e) || 999 }
      sorted.size > 5 ? (sorted.first(5) + ['…']) : sorted
    end
  end

  def has_validators?
    has_file_size_validator? && has_content_type_validator?
  end

  private

  def attribute_name
    attached_file.name
  end

  def has_content_type_validator?
    !content_type_validator.nil?
  end

  def has_file_size_validator?
    !file_size_validator.nil?
  end

  def file_size_validator
    record._validators[attribute_name.to_sym]
      &.find { |validator| validator.class == ActiveStorageValidations::SizeValidator }
  end

  def content_type_validator
    record._validators[attribute_name.to_sym]
      &.find { |validator| validator.class == ActiveStorageValidations::ContentTypeValidator }
  end

  def content_types_with_extensions(content_types)
    extensions = content_types.filter_map { |ct| MiniMime.lookup_by_content_type(ct)&.extension }
      .uniq
      .map { |ext| ".#{ext}" }

    (content_types + extensions).join(', ')
  end

  def accept_content_type
    list = content_type_validator_list.dup
    # Special case: acidcsa files are detected as octet-stream
    list << ".acidcsa" if list.include?("application/octet-stream")
    content_types_with_extensions(list)
  end

  # ASV accepts either an Array (options[:in]) or a Proc that returns an Array
  # (options[:with]). Normalize to an Array here.
  def content_type_validator_list
    options = content_type_validator.options
    raw = options[:in] || options[:with]
    raw.is_a?(Proc) ? Array.wrap(raw.call(record)) : Array.wrap(raw)
  end

  def accept_from_attached_type_de_champ
    return nil if champ.present?

    tdc = if record.is_a?(TypeDeChamp)
      record
    elsif record.respond_to?(:type_de_champ)
      record.type_de_champ
    end

    content_types = tdc&.send(:allowed_content_types).presence
    return nil if content_types.nil?

    content_types_with_extensions(content_types)
  end
end
