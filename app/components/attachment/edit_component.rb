# frozen_string_literal: true

# Display a widget for uploading, editing and deleting a file attachment
class Attachment::EditComponent < ApplicationComponent
  attr_reader :champ
  attr_reader :attachment
  attr_reader :attachments
  attr_reader :user_can_destroy
  alias user_can_destroy? user_can_destroy
  attr_reader :as_multiple
  alias as_multiple? as_multiple

  EXTENSIONS_ORDER = ['jpeg', 'png', 'pdf', 'zip'].freeze

  def initialize(champ: nil, auto_attach_url: nil, attached_file:, direct_upload: true, index: 0, as_multiple: false, view_as: :link, user_can_destroy: true, attachments: [], max: nil, aria_labelledby: nil, parent_hint_id: nil, **kwargs)
    @champ = champ
    @attached_file = attached_file
    @direct_upload = direct_upload
    @index = index
    @view_as = view_as
    @user_can_destroy = user_can_destroy
    @as_multiple = as_multiple
    @auto_attach_url = auto_attach_url

    # Adaptation pour la gestion des pièces jointes multiples
    @attachments = attachments.presence || (kwargs.key?(:attachment) ? [kwargs.delete(:attachment)] : [])
    @attachments << attached_file.attachment if attached_file.respond_to?(:attachment) && @attachments.empty?
    @attachments.compact!
    @max = max

    # Utilisation du premier attachement comme référence pour la rétrocompatibilité
    @attachment = @attachments.first

    # When parent form has nested attributes, pass the form builder object_name
    # to correctly infer the input attribute name.
    @form_object_name = kwargs.delete(:form_object_name)

    @aria_labelledby = aria_labelledby
    @parent_hint_id = parent_hint_id

    verify_initialization!(kwargs)
  end

  def explication?
    @attached_file.record.is_a?(TypeDeChamp) && @attached_file.record.explication?
  end

  def first?
    @index.zero?
  end

  def max_file_size
    if champ.present?
      return TypeDeChamp::IDENTITY_FILE_MAX_SIZE if champ.titre_identite? || champ.titre_identite_nature?
      return champ.max_file_size_bytes
    end

    return if file_size_validator.nil?

    file_size_validator.options[:less_than]
  end

  def attachment_id
    @attachment_id ||= (attachment&.id || SecureRandom.uuid)
  end

  def attachment_path(**args)
    helpers.attachment_path attachment.id, args.merge(signed_id: attachment.blob.signed_id)
  end

  def destroy_attachment_path
    if champ.present?
      attachment_path
    else
      attachment_path(auto_attach_url: @auto_attach_url, view_as: @view_as, direct_upload: @direct_upload)
    end
  end

  def attachment_input_class
    "attachment-input-#{attachment_id}"
  end

  def file_field_options
    track_issue_with_missing_validators if missing_validators?

    options = {
      class: class_names("fr-upload attachment-input": true, "#{attachment_input_class}": true),
      direct_upload: @direct_upload,
      id: input_id,
      data: {
        auto_attach_url:,
        turbo_force: :server,
        'enable-submit-if-uploaded-target': 'input',
      }.merge(max_file_size.present? ? { max_file_size: max_file_size } : {}),
    }

    describedby = []
    describedby << champ.describedby_id if champ&.description.present?
    describedby << @parent_hint_id if @parent_hint_id.present?
    describedby << champ.error_id(:value) if champ&.errors&.has_key?(:value)

    options[:aria] = { describedby: describedby.join(' '), labelledby: @aria_labelledby }

    accept = accept_from_type_de_champ || accept_from_attached_type_de_champ || (has_content_type_validator? ? accept_content_type : nil)
    options.merge!(accept.present? ? { accept: accept } : {})
    options[:multiple] = true if as_multiple?
    options[:disabled] = true if (@max && @index >= @max) || persisted?

    options
  end

  def poll_url
    if champ.present?
      auto_attach_url
    else
      attachment_path(user_can_edit: true, view_as: @view_as, auto_attach_url: @auto_attach_url, direct_upload: @direct_upload)
    end
  end

  def poll_context
    return :dossier if champ.present?

    nil
  end

  def field_name(object_name = nil, method_name = nil, *method_names, multiple: false, index: nil)
    field_name = @form_object_name || ActiveModel::Naming.param_key(@attached_file.record)
    "#{field_name}[#{attribute_name}]#{'[]' if as_multiple?}"
  end

  def attribute_name
    @attached_file.name
  end

  def remove_button_options
    {
      role: 'button',
      data: { turbo: "true", turbo_method: :delete },
    }
  end

  def replace_button_options
    {
      type: 'button',
      data: {
        action: "click->replace-attachment#open",
        auto_attach_url: auto_attach_url,
      }.compact,
    }
  end

  def retry_button_options
    {
      type: 'button',
      class: 'fr-btn fr-btn--sm fr-btn--tertiary fr-mt-1w attachment-upload-error-retry',
      data: { input_target: ".#{attachment_input_class}", action: 'autosave#onClickRetryButton' },
    }
  end

  def persisted?
    !!attachment&.persisted?
  end

  def downloadable?(attachment)
    return false unless @view_as == :download

    viewable?(attachment)
  end

  def viewable?(attachment)
    return false if attachment.virus_scanner_error?
    return false if attachment.watermark_pending?

    true
  end

  def error?(attachment)
    attachment.virus_scanner_error?
  end

  def error_message(attachment)
    case
    when attachment.virus_scanner.infected?
      t(".errors.virus_infected")
    when attachment.virus_scanner.corrupt?
      t(".errors.corrupted_file")
    end
  end

  private

  def describedby_hint_id
    "#{input_id}-pj-hint"
  end

  def input_id
    if champ.present?
      # There is always a single input by champ, its id must match the label "for" attribute.
      champ.focusable_input_id
    else
      dom_id(@attached_file.record, attribute_name)
    end
  end

  def auto_attach_url
    return @auto_attach_url if @auto_attach_url.present?
    return helpers.auto_attach_url(@champ) if @champ.present?

    nil
  end

  def file_size_validator
    @attached_file.record
      ._validators[attribute_name.to_sym]
      .find { |validator| validator.class == ActiveStorageValidations::SizeValidator }
  end

  def content_type_validator
    @attached_file.record
      ._validators[attribute_name.to_sym]
      .find { |validator| validator.class == ActiveStorageValidations::ContentTypeValidator }
  end

  def accept_content_type
    list = content_type_validator.options[:in].dup
    list << ".acidcsa" if list.include?("application/octet-stream")
    list.join(', ')
  end

  def accept_from_type_de_champ
    return nil if !champ&.respond_to?(:type_de_champ)

    if champ.titre_identite_nature? || champ.titre_identite?
      return FORMAT_FAMILIES[:image_scan].join(', ')
    end

    content_types = champ.type_de_champ.send(:allowed_content_types)
    return nil if content_types.blank?

    content_types.join(', ')
  end

  def accept_from_attached_type_de_champ
    record = @attached_file.record
    return nil if champ.present?

    tdc = if record.is_a?(TypeDeChamp)
      record
    elsif record.respond_to?(:type_de_champ)
      record.type_de_champ
    end

    content_types = tdc&.send(:allowed_content_types).presence
    content_types&.join(', ')
  end

  def allowed_formats
    @allowed_formats ||= begin
      if identity_context?
        tdc = champ.present? ? champ.type_de_champ : @attached_file.record
        return tdc.allowed_extensions.map { _1.delete_prefix('.') }
      end

      if champ.blank?
        record = @attached_file.record
        tdc = record.is_a?(TypeDeChamp) ? record : (record.respond_to?(:type_de_champ) ? record.type_de_champ : nil)
        if tdc.is_a?(TypeDeChamp)
          return tdc.allowed_extensions.map { _1.delete_prefix('.') } if tdc.RIB?

          # Pour les pièces jointes avec des formats limités, on affiche les formats autorisés
          if tdc.piece_justificative? && tdc.pj_limit_formats? && tdc.pj_format_families.present?
            return tdc.allowed_extensions.map { _1.delete_prefix('.') }
          end
        end
      end

      raw = if champ.present?
        champ.piece_justificative? ? champ.allowed_content_types : (has_content_type_validator? ? content_type_validator.options[:in] : [])
      elsif has_content_type_validator?
        content_type_validator.options[:in]
      else
        []
      end

      extensions = raw.filter_map { |ct| MiniMime.lookup_by_content_type(ct)&.extension }.uniq

      sorted_extensions = extensions.sort_by { |e| EXTENSIONS_ORDER.index(e) || 999 }
      sorted_extensions.size > 5 ? (sorted_extensions.first(5) + ['…']) : sorted_extensions
    end
  end

  def identity_context?
    return false if champ.blank? && !@attached_file.record.is_a?(TypeDeChamp)

    tdc = champ || @attached_file.record
    tdc.titre_identite? || tdc.titre_identite_nature?
  end

  def has_content_type_validator?
    !content_type_validator.nil?
  end

  def has_file_size_validator?
    !file_size_validator.nil?
  end

  def missing_validators?
    return true if !has_file_size_validator?
    return true if !has_content_type_validator?
    return false
  end

  def verify_initialization!(kwargs)
    fail ArgumentError, "Unknown kwarg #{kwargs.keys.join(', ')}" unless kwargs.empty?

    fail ArgumentError, "Invalid view_as:#{@view_as}, must be :download or :link" if [:download, :link].exclude?(@view_as)
  end

  def track_issue_with_missing_validators
    Sentry.capture_message(
      "Strange case of missing validator",
      extra: {
        champ: champ,
        field_name: field_name,
        attachment_id: attachment_id,
      }
    )
  end
end
