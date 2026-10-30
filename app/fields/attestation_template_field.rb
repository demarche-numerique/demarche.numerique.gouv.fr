# frozen_string_literal: true

require "administrate/field/base"

class AttestationTemplateField < Administrate::Field::Base
  def body_html
    doc = data.json_body.deep_symbolize_keys
    TiptapService.new.to_html(doc, TiptapService.label_placeholders(doc))
  end
end
