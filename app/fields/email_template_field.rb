# frozen_string_literal: true

require "administrate/field/base"

class EmailTemplateField < Administrate::Field::Base
  def name
    data.class::DISPLAYED_NAME
  end

  def subject_text
    doc = data.tiptap_subject_doc.deep_symbolize_keys
    TiptapService.new.to_texts_and_tags(doc, TiptapService.label_placeholders(doc), strip: false)
  end

  def body_html
    doc = data.tiptap_body_doc.deep_symbolize_keys
    TiptapService.new.to_html(doc, TiptapService.label_placeholders(doc))
  end
end
