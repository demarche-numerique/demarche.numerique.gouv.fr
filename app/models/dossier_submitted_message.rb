# frozen_string_literal: true

class DossierSubmittedMessage < ApplicationRecord
  has_many :revisions, class_name: 'ProcedureRevision', inverse_of: :dossier_submitted_message, dependent: :nullify

  def tiptap_body
    json_body&.to_json
  end

  def tiptap_body=(json)
    self.json_body = JSON.parse(json)
  end

  def tiptap_body_or_default
    if json_body.present?
      json_body.to_json
    elsif message_on_submit_by_usager.present?
      plain_text_to_tiptap_json(message_on_submit_by_usager).to_json
    else
      default_tiptap_json.to_json
    end
  end

  def body_as_html
    return nil if json_body.blank?
    TiptapService.new.to_html(json_body.deep_symbolize_keys)
  end

  def tiptap_content?
    json_body.present?
  end

  def body_as_text
    return nil if json_body.blank?
    TiptapService.to_plain_text(json_body.deep_symbolize_keys).squish
  end

  private

  # Provisoire : en attendant la MT T20260114backfillDossierSubmittedMessageJSONBodyTask
  def plain_text_to_tiptap_json(text)
    lines = text.to_s.split("\n").map(&:strip).compact_blank
    paragraphs = lines.map do |line|
      { "type" => "paragraph", "content" => [{ "type" => "text", "text" => line }] }
    end
    paragraphs = [{ "type" => "paragraph" }] if paragraphs.empty?
    { "type" => "doc", "content" => paragraphs }
  end

  def default_tiptap_json
    { "type" => "doc", "content" => [{ "type" => "paragraph" }] }
  end
end
