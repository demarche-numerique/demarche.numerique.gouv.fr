# frozen_string_literal: true

module ChampHelper
  def format_text_value(text)
    sanitized_text = html_escape(text)
    auto_linked_text = Anchored::Linker.auto_link(sanitized_text, target: '_blank', rel: 'noopener') do |link_href|
      truncate(link_href, length: 60)
    end
    simple_format(auto_linked_text, {}, sanitize: false)
  end

  # Attachments are normally submitted with their form. Champs are the
  # exception: the usager form auto-saves each champ on its own, so a piece
  # justificative is attached as soon as it is uploaded.
  def auto_attach_url(object)
    return if !object.is_a?(ChampData)

    champs_piece_justificative_url(object.dossier, object.stable_id, row_id: object.row_id)
  end
end
