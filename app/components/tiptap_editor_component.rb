# frozen_string_literal: true

class TiptapEditorComponent < ApplicationComponent
  DEFAULT_ACTIONS = %w[bold italic bulletList orderedList link].freeze

  BUTTONS = {
    'bold' => { icon: 'fr-icon-bold' },
    'italic' => { icon: 'fr-icon-italic' },
    'heading2' => { icon: 'fr-icon-h-1' },
    'heading3' => { icon: 'fr-icon-h-2' },
    'bulletList' => { icon: 'fr-icon-list-unordered' },
    'orderedList' => { icon: 'fr-icon-list-ordered' },
    'hardBreak' => { icon: 'fr-icon-corner-down-left-line' },
    'paragraph' => { icon: 'fr-icon-paragraph' },
  }.freeze

  attr_reader :form, :field_name, :preview_url, :actions, :tags, :label, :error_attribute

  # `collapsed_tags` hides the tag buttons behind a "Balises disponibles" toggle.
  # `error_attribute` renders the model errors of that attribute under the editor.
  def initialize(form:, field_name:, label:, preview_url: nil, actions: DEFAULT_ACTIONS, tags: nil,
    single_line: false, collapsed_tags: false, error_attribute: nil)
    @form = form
    @field_name = field_name
    @label = label
    @preview_url = preview_url
    @actions = actions
    @tags = tags
    @single_line = single_line
    @collapsed_tags = collapsed_tags
    @error_attribute = error_attribute
  end

  def input_value
    form.object.public_send("#{field_name}_or_default")
  end

  def simple_buttons
    actions.filter_map do |action|
      if (button = BUTTONS[action])
        label = t(".buttons.#{action}.label")
        title = t(".buttons.#{action}.title")
        button.merge(action: action, label: label, title: title)
      end
    end
  end

  def link?
    actions.include?('link')
  end

  def tags?
    tags.present?
  end

  def single_line?
    @single_line
  end

  def collapsed_tags?
    @collapsed_tags
  end

  def toolbar?
    simple_buttons.any? || link?
  end

  def errors?
    error_attribute.present? && form.object.errors.include?(error_attribute)
  end

  def editor_id
    form.field_id(field_name, :editor)
  end

  def errors_id
    form.field_id(field_name, :errors)
  end

  def tags_collapse_id
    form.field_id(field_name, :tags)
  end

  def data_attributes
    attributes = { controller: 'tiptap' }
    if preview_url
      attributes[:tiptap_preview_url_value] = preview_url
      # Lets a surrounding preview dossier picker point the preview at its dossier.
      attributes[:preview_dossier_target] = 'url'
      attributes[:preview_dossier_attribute] = 'data-tiptap-preview-url-value'
    end
    attributes[:tiptap_single_line_value] = true if single_line?
    attributes
  end
end
